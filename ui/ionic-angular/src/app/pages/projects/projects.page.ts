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

@Component({
  selector: 'app-projects',
  templateUrl: './projects.page.html',
  styleUrls: ['./projects.page.scss']
})
export class ProjectsPage {
  description = 'Browse all employee-linked projects, filter by department or status, and view team assignments.';

  projects: Project[] = [];
  employees: Employee[] = [];
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
    this.initialize().catch(() => {
      this.loadError = 'Unable to load project data.';
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

  async initialize(): Promise<void> {
    const [projects, employees] = await Promise.all([
      this.readJson<Project[]>('/data/projects.json'),
      this.readJson<Employee[]>('/data/employees.json')
    ]);

    this.projects = projects;
    this.employees = employees;
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
    return emp ? `${emp.displayName} (${emp.role}, ${emp.department})` : employeeId;
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
