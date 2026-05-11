import { Component } from '@angular/core';

// ── Layout constants ────────────────────────────────────────────────────────
const NODE_W = 162;
const NODE_H = 74;
const H_GAP  = 22;
const V_GAP  = 64;

// ── Types ───────────────────────────────────────────────────────────────────
type Employee = {
  employeeId: string;
  displayName: string;
  role: string;
  department: string;
  location: string;
  managerEmployeeId: string | null;
};

type Contribution = {
  employeeId: string;
  contributionScore: number;
  tier: string;
  projectCount: number;
  assetCount: number;
};

type OrgHierarchy = {
  topLevelManagers: string[];
  reportingGroups: Record<string, string[]>;
};

interface OrgNode {
  employeeId: string;
  displayName: string;
  role: string;
  department: string;
  location: string;
  children: OrgNode[];
  directReportCount: number;
  totalReportCount: number;
  avgScore: number;
  contributionScore: number;
  tier: string;
  projectCount: number;
  assetCount: number;
  // layout (filled by layoutTree)
  subtreeWidth: number;
  x: number;
  y: number;
}

export type RenderedNode = {
  node: OrgNode;
  cx: number; // center-x of node box
  cy: number; // top-y of node box
};

export type RenderedEdge = {
  x1: number; y1: number;
  x2: number; y2: number;
};

// ── Component ────────────────────────────────────────────────────────────────
@Component({
  selector: 'app-org-chart',
  templateUrl: './org-chart.page.html',
  styleUrls: ['./org-chart.page.scss']
})
export class OrgChartPage {
  description = 'Graphical org chart showing the reporting structure for all employees, with KPIs on direct and total reports per manager. Click any node to inspect.';

  employees: Employee[] = [];
  contributions: Contribution[] = [];
  hierarchy!: OrgHierarchy;

  // all top-level roots (built from hierarchy)
  private rootNodes: OrgNode[] = [];

  // currently rendered tree (may be a subtree)
  renderedNodes: RenderedNode[] = [];
  renderedEdges: RenderedEdge[] = [];
  svgWidth  = 0;
  svgHeight = 0;

  // controls
  focusManagerId = '';   // '' = show all top-level + their L1 reports
  departmentFilter = '';
  departments: string[] = [];
  topManagers: Employee[] = [];
  midManagers: Employee[] = [];

  // selected node detail
  selectedNode?: OrgNode;

  loadError = '';

  // expose layout constants to template
  readonly NODE_W = NODE_W;
  readonly NODE_H = NODE_H;

  constructor() {
    this.initialize().catch((err: unknown) => {
      this.loadError = `Unable to load org chart data: ${err instanceof Error ? err.message : String(err)}`;
    });
  }

  // ── KPI summary getters ──────────────────────────────────────────────────
  get totalEmployees(): number { return this.employees.length; }

  get totalManagers(): number {
    return this.employees.filter((e) =>
      this.hierarchy ? (e.employeeId in this.hierarchy.reportingGroups) : false
    ).length;
  }

  get avgSpanOfControl(): number {
    const mgrs = this.employees.filter((e) =>
      this.hierarchy && (e.employeeId in this.hierarchy.reportingGroups)
    );
    if (mgrs.length === 0) return 0;
    const totalReports = mgrs.reduce((s, m) =>
      s + (this.hierarchy.reportingGroups[m.employeeId]?.length ?? 0), 0);
    return Math.round((totalReports / mgrs.length) * 10) / 10;
  }

  get maxDepth(): number { return 3; }

  // ── Load ─────────────────────────────────────────────────────────────────
  async initialize(): Promise<void> {
    const [employees, contributions, hierarchy] = await Promise.all([
      this.readJson<Employee[]>('/api/employees'),
      this.readJson<Contribution[]>('/api/contributions'),
      this.readJson<OrgHierarchy>('/api/org-hierarchy')
    ]);
    this.employees    = employees;
    this.contributions = contributions;
    this.hierarchy    = hierarchy;

    this.departments = [...new Set(employees.map((e) => e.department))].sort();
    this.topManagers = hierarchy.topLevelManagers
      .map((id) => employees.find((e) => e.employeeId === id))
      .filter((e): e is Employee => !!e);
    this.midManagers = Object.keys(hierarchy.reportingGroups)
      .filter((id) => !hierarchy.topLevelManagers.includes(id))
      .map((id) => employees.find((e) => e.employeeId === id))
      .filter((e): e is Employee => !!e);

    // Build all root nodes (full tree), then render default view
    this.rootNodes = hierarchy.topLevelManagers.map((id) => this.buildNode(id));
    this.renderView();
  }

  // ── Controls ──────────────────────────────────────────────────────────────
  onFocusManager(id: string): void {
    this.focusManagerId = id;
    this.selectedNode = undefined;
    this.renderView();
  }

  onDepartmentFilter(dept: string): void {
    this.departmentFilter = dept;
  }

  clearFocus(): void {
    this.focusManagerId = '';
    this.selectedNode = undefined;
    this.renderView();
  }

  selectNode(node: OrgNode): void {
    this.selectedNode = node;
  }

  // ── Rendering ─────────────────────────────────────────────────────────────
  private renderView(): void {
    let roots: OrgNode[];

    if (this.focusManagerId) {
      // Focused: find the node in any root subtree
      const found = this.findNode(this.rootNodes, this.focusManagerId);
      roots = found ? [found] : this.rootNodes;
    } else {
      // Default: show top-level managers and their direct reports only (2 levels)
      roots = this.rootNodes.map((root) => this.cloneShallow(root, 2));
    }

    // Lay out the forest (multiple roots side by side)
    const nodes: RenderedNode[] = [];
    const edges: RenderedEdge[] = [];

    let offsetX = 20;
    for (const root of roots) {
      computeSubtreeWidth(root);
      layoutNode(root, offsetX, 20);
      collectNodes(root, nodes);
      collectEdges(root, edges);
      offsetX += root.subtreeWidth + H_GAP * 2;
    }

    this.renderedNodes = nodes;
    this.renderedEdges = edges;

    const maxX = nodes.reduce((m, n) => Math.max(m, n.cx + NODE_W / 2 + 20), 400);
    const maxY = nodes.reduce((m, n) => Math.max(m, n.cy + NODE_H + 20), 200);
    this.svgWidth  = maxX;
    this.svgHeight = maxY;
  }

  // ── Tree construction ─────────────────────────────────────────────────────
  private buildNode(empId: string): OrgNode {
    const emp   = this.employees.find((e) => e.employeeId === empId);
    const contrib = this.contributions.find((c) => c.employeeId === empId);
    const directIds = this.hierarchy.reportingGroups[empId] ?? [];
    const children  = directIds.map((id) => this.buildNode(id));

    const directReportCount = directIds.length;
    const totalReportCount  = directReportCount + children.reduce((s, c) => s + c.totalReportCount, 0);

    const allScores = this.getAllScores(empId);
    const avgScore  = allScores.length
      ? Math.round(allScores.reduce((a, b) => a + b, 0) / allScores.length)
      : 0;

    return {
      employeeId: empId,
      displayName: emp?.displayName ?? empId,
      role: emp?.role ?? '',
      department: emp?.department ?? '',
      location: emp?.location ?? '',
      children,
      directReportCount,
      totalReportCount,
      avgScore,
      contributionScore: contrib?.contributionScore ?? 0,
      tier: contrib?.tier ?? '',
      projectCount: contrib?.projectCount ?? 0,
      assetCount: contrib?.assetCount ?? 0,
      subtreeWidth: NODE_W,
      x: 0,
      y: 0
    };
  }

  /** Collect all descendant scores for avg calculation */
  private getAllScores(empId: string): number[] {
    const contrib = this.contributions.find((c) => c.employeeId === empId);
    const own = contrib ? [contrib.contributionScore] : [];
    const directIds = this.hierarchy.reportingGroups[empId] ?? [];
    return [...own, ...directIds.flatMap((id) => this.getAllScores(id))];
  }

  /** Clone a node tree only down to `maxDepth` levels */
  private cloneShallow(node: OrgNode, depth: number): OrgNode {
    return {
      ...node,
      children: depth > 1 ? node.children.map((c) => this.cloneShallow(c, depth - 1)) : []
    };
  }

  private findNode(roots: OrgNode[], id: string): OrgNode | undefined {
    for (const r of roots) {
      if (r.employeeId === id) return r;
      const found = this.findNode(r.children, id);
      if (found) return found;
    }
    return undefined;
  }

  // ── Template helpers ──────────────────────────────────────────────────────
  getEdgePath(edge: RenderedEdge): string {
    return `M ${edge.x1} ${edge.y1} C ${edge.x1} ${edge.y1 + 30} ${edge.x2} ${edge.y2 - 30} ${edge.x2} ${edge.y2}`;
  }

  scoreColor(score: number): string {
    if (score >= 80) return '#2d7d46';
    if (score >= 55) return '#d4832a';
    return '#b91c1c';
  }

  nodeFill(node: OrgNode): string {
    if (this.departmentFilter && node.department !== this.departmentFilter) return '#f0f0f0';
    if (node.tier === 'star')    return '#fff8e6';
    if (node.children.length > 0) return '#e8f3ff';
    return '#ffffff';
  }

  nodeBorder(node: OrgNode): string {
    if (this.selectedNode?.employeeId === node.employeeId) return '#005a9e';
    if (this.departmentFilter && node.department !== this.departmentFilter) return '#ccc';
    if (node.tier === 'star')    return '#d4832a';
    if (node.children.length > 0) return '#0078d4';
    return '#d0d7de';
  }

  nodeTierBadge(node: OrgNode): string {
    return node.tier === 'star' ? '⭐' : node.children.length > 0 ? '👔' : '';
  }

  initials(name: string): string {
    return name.split(' ').map((n) => n[0]).join('').slice(0, 2);
  }

  get focusedManagerName(): string {
    return this.employees.find((e) => e.employeeId === this.focusManagerId)?.displayName ?? '';
  }

  private async readJson<T>(url: string): Promise<T> {
    const response = await fetch(url);
    if (!response.ok) throw new Error(`Failed to load ${url}: ${response.status}`);
    return response.json() as Promise<T>;
  }
}

// ── Tree layout helpers (module-level, pure functions) ───────────────────────

function computeSubtreeWidth(node: OrgNode): number {
  if (node.children.length === 0) {
    node.subtreeWidth = NODE_W;
    return NODE_W;
  }
  const childrenTotal = node.children.reduce(
    (s, c) => s + computeSubtreeWidth(c) + H_GAP, -H_GAP
  );
  node.subtreeWidth = Math.max(NODE_W, childrenTotal);
  return node.subtreeWidth;
}

function layoutNode(node: OrgNode, left: number, top: number): void {
  // Center the node box within its subtree allocation
  node.x = left + (node.subtreeWidth - NODE_W) / 2;
  node.y = top;

  if (node.children.length === 0) return;

  let childLeft = left;
  for (const child of node.children) {
    layoutNode(child, childLeft, top + NODE_H + V_GAP);
    childLeft += child.subtreeWidth + H_GAP;
  }
}

function collectNodes(node: OrgNode, out: RenderedNode[]): void {
  out.push({ node, cx: node.x, cy: node.y });
  for (const child of node.children) collectNodes(child, out);
}

function collectEdges(node: OrgNode, out: RenderedEdge[]): void {
  const parentCx = node.x + NODE_W / 2;
  const parentBottom = node.y + NODE_H;
  for (const child of node.children) {
    const childCx = child.x + NODE_W / 2;
    out.push({ x1: parentCx, y1: parentBottom, x2: childCx, y2: child.y });
    collectEdges(child, out);
  }
}
