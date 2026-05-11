import { Component } from '@angular/core';

type Contribution = {
  employeeId: string;
  department: string;
  location: string;
  projectIds: string[];
  projectCount: number;
  activeProjectCount: number;
  completedProjectCount: number;
  assetCount: number;
  presentationCount: number;
  documentCount: number;
  reportCount: number;
  emailActivityCount: number;
  mentoringSessionCount: number;
  codeCommitCount: number;
  contributionScore: number;
  tier: string;
};

type Employee = {
  employeeId: string;
  displayName: string;
  department: string;
  role: string;
  location: string;
};

type PieSlice = {
  department: string;
  count: number;
  avgScore: number;
  color: string;
  startAngle: number;
  endAngle: number;
  pathD: string;
};

const DEPT_COLORS: Record<string, string> = {
  Manufacturing: '#0078d4',
  IT: '#2d7d46',
  HR: '#8a63d2',
  Finance: '#d4832a',
  'R&D': '#e74c3c',
  Operations: '#16a085',
  Engineering: '#f39c12',
  Procurement: '#8e44ad'
};

function colorForDept(dept: string): string {
  return DEPT_COLORS[dept] ?? '#607d8b';
}

function pieSlicePath(cx: number, cy: number, r: number, startAngle: number, endAngle: number): string {
  const s = (startAngle * Math.PI) / 180;
  const e = (endAngle * Math.PI) / 180;
  const x1 = cx + r * Math.cos(s);
  const y1 = cy + r * Math.sin(s);
  const x2 = cx + r * Math.cos(e);
  const y2 = cy + r * Math.sin(e);
  const large = endAngle - startAngle > 180 ? 1 : 0;
  return `M ${cx} ${cy} L ${x1} ${y1} A ${r} ${r} 0 ${large} 1 ${x2} ${y2} Z`;
}

@Component({
  selector: 'app-leaderboard',
  templateUrl: './leaderboard.page.html',
  styleUrls: ['./leaderboard.page.scss']
})
export class LeaderboardPage {
  description = 'Top contributor leaderboards with bar charts, department pie charts, and location breakdown. Filter by department.';

  employees: Employee[] = [];
  contributions: Contribution[] = [];

  departmentFilter = '';
  departments: string[] = [];

  loadError = '';

  constructor() {
    this.initialize().catch((err: unknown) => {
      this.loadError = `Unable to load leaderboard data: ${err instanceof Error ? err.message : String(err)}`;
    });
  }

  async initialize(): Promise<void> {
    const [employees, contributions] = await Promise.all([
      this.readJson<Employee[]>('/api/employees'),
      this.readJson<Contribution[]>('/api/contributions')
    ]);
    this.employees = employees;
    this.contributions = contributions;
    this.departments = [...new Set(contributions.map((c) => c.department))].sort();
  }

  onDepartmentFilter(value: string): void {
    this.departmentFilter = value;
  }

  clearFilter(): void {
    this.departmentFilter = '';
  }

  get filtered(): Contribution[] {
    if (!this.departmentFilter) return this.contributions;
    return this.contributions.filter((c) => c.department === this.departmentFilter);
  }

  get topContributors(): Contribution[] {
    return [...this.filtered]
      .sort((a, b) => b.contributionScore - a.contributionScore)
      .slice(0, 10);
  }

  get maxScore(): number {
    return this.topContributors[0]?.contributionScore ?? 100;
  }

  employeeName(employeeId: string): string {
    return this.employees.find((e) => e.employeeId === employeeId)?.displayName ?? employeeId;
  }

  employeeRole(employeeId: string): string {
    const emp = this.employees.find((e) => e.employeeId === employeeId);
    return emp ? `${emp.role} · ${emp.department}` : '';
  }

  scoreColor(score: number): string {
    if (score >= 80) return '#2d7d46';
    if (score >= 55) return '#d4832a';
    return '#b91c1c';
  }

  barColor(employeeId: string): string {
    const emp = this.employees.find((e) => e.employeeId === employeeId);
    return colorForDept(emp?.department ?? '');
  }

  /** Pie chart: department distribution */
  get pieSlices(): PieSlice[] {
    const data = this.filtered;
    const deptMap = new Map<string, number[]>();
    for (const c of data) {
      const arr = deptMap.get(c.department) ?? [];
      arr.push(c.contributionScore);
      deptMap.set(c.department, arr);
    }

    const total = data.length;
    if (total === 0) return [];

    const slices: PieSlice[] = [];
    let angle = -90;

    for (const [dept, scores] of deptMap.entries()) {
      const count = scores.length;
      const avgScore = Math.round(scores.reduce((a, b) => a + b, 0) / count);
      const sweep = (count / total) * 360;
      const endAngle = angle + sweep;
      slices.push({
        department: dept,
        count,
        avgScore,
        color: colorForDept(dept),
        startAngle: angle,
        endAngle,
        pathD: pieSlicePath(100, 100, 90, angle, endAngle)
      });
      angle = endAngle;
    }
    return slices;
  }

  /** Location distribution table */
  get locationStats(): { location: string; count: number; avgScore: number; topEmployee: string }[] {
    const data = this.filtered;
    const locMap = new Map<string, { scores: number[]; empIds: string[] }>();
    for (const c of data) {
      const entry = locMap.get(c.location) ?? { scores: [], empIds: [] };
      entry.scores.push(c.contributionScore);
      entry.empIds.push(c.employeeId);
      locMap.set(c.location, entry);
    }

    return Array.from(locMap.entries())
      .map(([location, { scores, empIds }]) => {
        const maxIdx = scores.indexOf(Math.max(...scores));
        return {
          location,
          count: scores.length,
          avgScore: Math.round(scores.reduce((a, b) => a + b, 0) / scores.length),
          topEmployee: this.employeeName(empIds[maxIdx])
        };
      })
      .sort((a, b) => b.avgScore - a.avgScore);
  }

  /** Asset type breakdown across all filtered employees */
  get assetBreakdown(): { label: string; total: number; color: string }[] {
    const data = this.filtered;
    const pres = data.reduce((s, c) => s + c.presentationCount, 0);
    const docs = data.reduce((s, c) => s + c.documentCount, 0);
    const rpts = data.reduce((s, c) => s + c.reportCount, 0);
    const other = data.reduce((s, c) => s + Math.max(0, c.assetCount - c.presentationCount - c.documentCount - c.reportCount), 0);
    return [
      { label: 'Presentations', total: pres, color: '#0078d4' },
      { label: 'Documents', total: docs, color: '#2d7d46' },
      { label: 'Reports', total: rpts, color: '#8a63d2' },
      { label: 'Other', total: other, color: '#d4832a' }
    ];
  }

  get assetBreakdownMax(): number {
    return Math.max(...this.assetBreakdown.map((a) => a.total), 1);
  }

  tierCount(tier: string): number {
    return this.filtered.filter((c) => c.tier === tier).length;
  }

  private async readJson<T>(url: string): Promise<T> {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Failed to load ${url}: ${response.status} ${response.statusText}`);
    }
    return response.json() as Promise<T>;
  }
}
