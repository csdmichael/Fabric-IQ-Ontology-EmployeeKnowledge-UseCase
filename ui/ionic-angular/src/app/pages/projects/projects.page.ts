import { Component } from '@angular/core';

type Project = {
  projectId: string;
  name: string;
  description: string;
  department: string;
  status: string;
  startDate: string;
  endDate: string | null;
  employeeIds: string[];
  skills: string[];
};

type Employee = {
  employeeId: string;
  displayName: string;
  department: string;
  role: string;
};

type Contribution = {
  employeeId: string;
  contributionScore: number;
  tier: string;
  projectIds: string[];
};

@Component({
  selector: 'app-projects',
  templateUrl: './projects.page.html',
  styleUrls: ['./projects.page.scss']
})
export class ProjectsPage {
  description = 'Browse all employee-linked projects, filter by department or status, and view team assignments with project KPIs.';

  projects: Project[] = [];
  employees: Employee[] = [];
  contributions: Contribution[] = [];
  filteredProjects: Project[] = [];

  query = '';
  statusFilter = '';
  departmentFilter = '';

  departments: string[] = [];
  statuses: string[] = [];

  page = 1;
  readonly pageSize = 8;

  selectedProject?: Project;
  loadError = '';

  constructor() {
    this.initialize().catch((error: unknown) => {
      this.loadError = `Unable to load project data: ${error instanceof Error ? error.message : String(error)}`;
    });
  }

  get totalProjects(): number {
    return this.filteredProjects.length;
  }

  get totalPages(): number {
    return Math.max(1, Math.ceil(this.totalProjects / this.pageSize));
  }

  get pagedProjects(): Project[] {
    const start = (this.page - 1) * this.pageSize;
    return this.filteredProjects.slice(start, start + this.pageSize);
  }

  /** KPIs for the currently selected project */
  get selectedProjectKpis(): { activeCount: number; completedCount: number; avgScore: number; topContributor: string; skillCount: number } | null {
    if (!this.selectedProject) return null;
    const proj = this.selectedProject;
    const members = proj.employeeIds
      .map((id) => this.contributions.find((c) => c.employeeId === id))
      .filter((c): c is Contribution => !!c);

    const avgScore = members.length
      ? Math.round(members.reduce((s, c) => s + c.contributionScore, 0) / members.length)
      : 0;

    const top = members.sort((a, b) => b.contributionScore - a.contributionScore)[0];
    const topName = top ? (this.employees.find((e) => e.employeeId === top.employeeId)?.displayName ?? top.employeeId) : '—';

    return {
      activeCount: proj.employeeIds.length,
      completedCount: proj.status === 'Completed' ? proj.employeeIds.length : 0,
      avgScore,
      topContributor: topName,
      skillCount: proj.skills.length
    };
  }

  /** Portfolio KPIs across all filtered projects */
  get portfolioKpis(): { total: number; active: number; completed: number; planning: number; avgTeamSize: number } {
    const proj = this.filteredProjects;
    const active = proj.filter((p) => p.status === 'Active').length;
    const completed = proj.filter((p) => p.status === 'Completed').length;
    const planning = proj.filter((p) => p.status === 'Planning').length;
    const avgTeamSize = proj.length
      ? Math.round(proj.reduce((s, p) => s + p.employeeIds.length, 0) / proj.length)
      : 0;
    return { total: proj.length, active, completed, planning, avgTeamSize };
  }

  async initialize(): Promise<void> {
    const [projects, employees, contributions] = await Promise.all([
      this.readJson<Project[]>('/data/projects.json'),
      this.readJson<Employee[]>('/data/employees.json'),
      this.readJson<Contribution[]>('/data/contributions.json')
    ]);

    this.projects = projects;
    this.employees = employees;
    this.contributions = contributions;
    this.filteredProjects = [...projects];

    this.departments = [...new Set(projects.map((p) => p.department))].sort();
    this.statuses = [...new Set(projects.map((p) => p.status))].sort();
  }

  onQueryInput(value: string): void {
    this.query = value;
    this.applyFilters();
  }

  onStatusFilter(value: string): void {
    this.statusFilter = value;
    this.applyFilters();
  }

  onDepartmentFilter(value: string): void {
    this.departmentFilter = value;
    this.applyFilters();
  }

  clearFilters(): void {
    this.query = '';
    this.statusFilter = '';
    this.departmentFilter = '';
    this.filteredProjects = [...this.projects];
    this.page = 1;
    this.selectedProject = undefined;
  }

  selectProject(project: Project): void {
    this.selectedProject = project;
  }

  goToPreviousPage(): void {
    if (this.page > 1) {
      this.page -= 1;
    }
  }

  goToNextPage(): void {
    if (this.page < this.totalPages) {
      this.page += 1;
    }
  }

  employeeDisplay(employeeId: string): string {
    const emp = this.employees.find((e) => e.employeeId === employeeId);
    const contrib = this.contributions.find((c) => c.employeeId === employeeId);
    const score = contrib ? ` · Score: ${contrib.contributionScore}` : '';
    return emp ? `${emp.displayName} (${emp.role}, ${emp.department})${score}` : employeeId;
  }

  employeeScore(employeeId: string): number {
    return this.contributions.find((c) => c.employeeId === employeeId)?.contributionScore ?? 0;
  }

  scoreColor(score: number): string {
    if (score >= 80) return 'success';
    if (score >= 55) return 'warning';
    return 'danger';
  }

  statusColor(status: string): string {
    switch (status) {
      case 'Active':    return 'success';
      case 'Completed': return 'medium';
      case 'Planning':  return 'warning';
      default:          return 'primary';
    }
  }

  private applyFilters(): void {
    const normalized = this.query.trim().toLowerCase();

    this.filteredProjects = this.projects.filter((p) => {
      const matchesQuery =
        !normalized ||
        p.name.toLowerCase().includes(normalized) ||
        p.description.toLowerCase().includes(normalized) ||
        p.projectId.toLowerCase().includes(normalized) ||
        p.skills.some((s) => s.toLowerCase().includes(normalized)) ||
        p.employeeIds.some((id) => id.toLowerCase().includes(normalized));

      const matchesStatus = !this.statusFilter || p.status === this.statusFilter;
      const matchesDept = !this.departmentFilter || p.department === this.departmentFilter;

      return matchesQuery && matchesStatus && matchesDept;
    });

    this.page = 1;
  }

  private async readJson<T>(url: string): Promise<T> {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Failed to load ${url}: ${response.status} ${response.statusText}`);
    }
    return response.json() as Promise<T>;
  }
}
