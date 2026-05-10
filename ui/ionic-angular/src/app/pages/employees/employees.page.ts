import { Component } from '@angular/core';

type Employee = {
  employeeId: string;
  displayName: string;
  email: string;
  department: string;
  role: string;
  location: string;
  skills: string[];
  hireDate: string;
  managerEmployeeId: string | null;
};

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

@Component({
  selector: 'app-employees',
  templateUrl: './employees.page.html',
  styleUrls: ['./employees.page.scss']
})
export class EmployeesPage {
  description = 'Browse all employees, explore contribution KPIs by project and digital assets, and filter or group by department.';

  employees: Employee[] = [];
  contributions: Contribution[] = [];
  projects: Project[] = [];

  filteredEmployees: Employee[] = [];

  query = '';
  departmentFilter = '';
  groupByDepartment = false;

  departments: string[] = [];
  page = 1;
  readonly pageSize = 15;

  selectedEmployee?: Employee;
  loadError = '';

  constructor() {
    this.initialize().catch((err: unknown) => {
      this.loadError = `Unable to load employee data: ${err instanceof Error ? err.message : String(err)}`;
    });
  }

  get totalEmployees(): number {
    return this.filteredEmployees.length;
  }

  get totalPages(): number {
    return Math.max(1, Math.ceil(this.totalEmployees / this.pageSize));
  }

  get pagedEmployees(): Employee[] {
    const start = (this.page - 1) * this.pageSize;
    return this.filteredEmployees.slice(start, start + this.pageSize);
  }

  get groupedEmployees(): { department: string; employees: Employee[] }[] {
    const map = new Map<string, Employee[]>();
    for (const emp of this.filteredEmployees) {
      const list = map.get(emp.department) ?? [];
      list.push(emp);
      map.set(emp.department, list);
    }
    return Array.from(map.entries())
      .sort((a, b) => a[0].localeCompare(b[0]))
      .map(([department, employees]) => ({ department, employees }));
  }

  async initialize(): Promise<void> {
    const [employees, contributions, projects] = await Promise.all([
      this.readJson<Employee[]>('/data/employees.json'),
      this.readJson<Contribution[]>('/data/contributions.json'),
      this.readJson<Project[]>('/data/projects.json')
    ]);

    this.employees = employees;
    this.contributions = contributions;
    this.projects = projects;
    this.filteredEmployees = [...employees];
    this.departments = [...new Set(employees.map((e) => e.department))].sort();
  }

  onQueryInput(value: string): void {
    this.query = value;
    this.applyFilters();
  }

  onDepartmentFilter(value: string): void {
    this.departmentFilter = value;
    this.applyFilters();
  }

  clearFilters(): void {
    this.query = '';
    this.departmentFilter = '';
    this.filteredEmployees = [...this.employees];
    this.page = 1;
    this.selectedEmployee = undefined;
  }

  selectEmployee(emp: Employee): void {
    this.selectedEmployee = emp;
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

  contributionFor(employeeId: string): Contribution | undefined {
    return this.contributions.find((c) => c.employeeId === employeeId);
  }

  scoreColor(score: number): string {
    if (score >= 80) return 'success';
    if (score >= 55) return 'warning';
    return 'danger';
  }

  tierLabel(tier: string): string {
    return tier === 'star' ? '⭐ Star' : tier === 'low' ? '📉 Developing' : '📊 Average';
  }

  tierColor(tier: string): string {
    return tier === 'star' ? 'success' : tier === 'low' ? 'medium' : 'primary';
  }

  projectsForEmployee(employeeId: string): Project[] {
    const contrib = this.contributionFor(employeeId);
    if (!contrib) return [];
    return this.projects.filter((p) => contrib.projectIds.includes(p.projectId));
  }

  /** SVG bar chart data for contribution breakdown */
  barData(contrib: Contribution): { label: string; value: number; max: number; color: string }[] {
    const max = Math.max(contrib.projectCount * 10, contrib.assetCount, contrib.codeCommitCount, contrib.emailActivityCount, 30);
    return [
      { label: 'Projects', value: contrib.projectCount * 10, max, color: '#0078d4' },
      { label: 'Assets', value: contrib.assetCount, max, color: '#2d7d46' },
      { label: 'Commits', value: contrib.codeCommitCount, max, color: '#8a63d2' },
      { label: 'Emails', value: contrib.emailActivityCount, max, color: '#d4832a' }
    ];
  }

  private applyFilters(): void {
    const normalized = this.query.trim().toLowerCase();
    this.filteredEmployees = this.employees.filter((emp) => {
      const matchesQuery =
        !normalized ||
        emp.displayName.toLowerCase().includes(normalized) ||
        emp.employeeId.toLowerCase().includes(normalized) ||
        emp.email.toLowerCase().includes(normalized) ||
        emp.role.toLowerCase().includes(normalized) ||
        emp.location.toLowerCase().includes(normalized) ||
        emp.skills.some((s) => s.toLowerCase().includes(normalized));
      const matchesDept = !this.departmentFilter || emp.department === this.departmentFilter;
      return matchesQuery && matchesDept;
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
