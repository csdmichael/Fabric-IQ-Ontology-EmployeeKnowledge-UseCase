import { Component } from '@angular/core';

type PowerBIReport = {
  reportId: string;
  name: string;
  description: string;
  workspaceId: string;
  datasetId: string;
  embedUrl: string;
  department: string;
  refreshSchedule: string;
  tags: string[];
};

@Component({
  selector: 'app-powerbi-reports',
  templateUrl: './powerbi-reports.page.html',
  styleUrls: ['./powerbi-reports.page.scss']
})
export class PowerBIReportsPage {
  description = 'Embedded Power BI reports and dashboards built on Microsoft Fabric, covering employee contributions, project portfolio, leaderboards, and geographic analytics.';

  reports: PowerBIReport[] = [];
  filteredReports: PowerBIReport[] = [];

  departmentFilter = '';
  departments: string[] = [];

  selectedReport?: PowerBIReport;
  loadError = '';

  embedMode: 'placeholder' | 'iframe' = 'placeholder';

  constructor() {
    this.initialize().catch((err: unknown) => {
      this.loadError = `Unable to load Power BI report data: ${err instanceof Error ? err.message : String(err)}`;
    });
  }

  async initialize(): Promise<void> {
    const reports = await this.readJson<PowerBIReport[]>('/fabric/powerbi/powerbi_reports.json');
    this.reports = reports;
    this.filteredReports = [...reports];
    this.departments = [...new Set(reports.map((r) => r.department))].sort();
  }

  onDepartmentFilter(value: string): void {
    this.departmentFilter = value;
    this.applyFilters();
  }

  clearFilters(): void {
    this.departmentFilter = '';
    this.filteredReports = [...this.reports];
    this.selectedReport = undefined;
  }

  selectReport(report: PowerBIReport): void {
    this.selectedReport = report;
    this.embedMode = 'placeholder';
  }

  openEmbed(): void {
    this.embedMode = 'iframe';
  }

  tagIcon(tag: string): string {
    const map: Record<string, string> = {
      employees: '👥', KPIs: '📊', contributions: '📈', projects: '🗂️',
      portfolio: '📋', status: '🏷️', leaderboard: '🏆', ranking: '🥇',
      skills: '🎓', departments: '🏢', heatmap: '🗺️', assets: '📂',
      digital: '💾', analytics: '🔍', HR: '👔', attrition: '📉',
      talent: '⭐', geography: '🌍', locations: '📍', ontology: '🔗',
      'knowledge graph': '🕸️', 'Fabric IQ': '⚡', 'top contributors': '🏅'
    };
    return map[tag] ?? '🔹';
  }

  scheduleColor(schedule: string): string {
    switch (schedule) {
      case 'Daily': return 'success';
      case 'Weekly': return 'primary';
      case 'Monthly': return 'warning';
      default: return 'medium';
    }
  }

  private applyFilters(): void {
    this.filteredReports = this.reports.filter((r) =>
      !this.departmentFilter || r.department === this.departmentFilter || r.department === 'All'
    );
  }

  private async readJson<T>(url: string): Promise<T> {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Failed to load ${url}: ${response.status} ${response.statusText}`);
    }
    return response.json() as Promise<T>;
  }
}
