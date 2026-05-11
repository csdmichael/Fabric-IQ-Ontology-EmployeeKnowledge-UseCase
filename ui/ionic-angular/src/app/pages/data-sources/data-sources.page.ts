import { Component } from '@angular/core';
import { ConfigService } from '../../services/config.service';

type Employee = {
  employeeId: string;
  displayName: string;
  email: string;
  department: string;
  role: string;
  location: string;
};

type Asset = {
  assetId: string;
  employeeId: string;
  assetType: string;
  format: string;
  title: string;
  sourceSystem: string;
  lastModified: string;
  storageRef: {
    container: string;
    relativePath: string;
    endpointConfigKey: string;
  };
};

@Component({
  selector: 'app-data-sources',
  templateUrl: './data-sources.page.html',
  styleUrls: ['./data-sources.page.scss']
})
export class DataSourcesPage {
  description = 'Search employees and assets, paginate results, and preview supported files in-browser.';

  private readonly configService = new ConfigService();

  employees: Employee[] = [];
  assets: Asset[] = [];
  filteredAssets: Asset[] = [];

  query = '';
  suggestions: string[] = [];

  page = 1;
  readonly pageSize = 12;

  selectedAsset?: Asset;
  previewType: 'iframe' | 'text' | 'unsupported' | 'none' = 'none';
  previewUrl = '';
  previewText = '';
  previewError = '';

  constructor() {
    this.initialize().catch(() => {
      this.previewError = 'Unable to load employee asset data for preview.';
    });
  }

  get totalAssets(): number {
    return this.filteredAssets.length;
  }

  get totalPages(): number {
    return Math.max(1, Math.ceil(this.totalAssets / this.pageSize));
  }

  get pagedAssets(): Asset[] {
    const start = (this.page - 1) * this.pageSize;
    return this.filteredAssets.slice(start, start + this.pageSize);
  }

  async initialize(): Promise<void> {
    const [employees, assets] = await Promise.all([
      this.readJson<Employee[]>('/data/employees.json'),
      this.readJson<Asset[]>('/data/digital_assets.json')
    ]);

    this.employees = employees;
    this.assets = assets;
    this.filteredAssets = [...assets];
    this.updateSuggestions();
  }

  onQueryInput(value: string): void {
    this.query = value;
    this.applyFilters();
  }

  applySuggestion(suggestion: string): void {
    this.query = suggestion;
    this.applyFilters();
  }

  clearFilters(): void {
    this.query = '';
    this.filteredAssets = [...this.assets];
    this.page = 1;
    this.updateSuggestions();
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

  async previewAsset(asset: Asset): Promise<void> {
    this.selectedAsset = asset;
    this.previewType = 'none';
    this.previewText = '';
    this.previewUrl = '';
    this.previewError = '';

    const sourceUrl = await this.resolveAssetSourceUrl(asset);
    const fmt = asset.format.toLowerCase();

    if (fmt === 'pdf') {
      this.previewType = 'iframe';
      this.previewUrl = sourceUrl;
      return;
    }

    if (['pptx', 'docx', 'xlsx', 'one'].includes(fmt)) {
      this.previewType = 'iframe';
      this.previewUrl = `https://view.officeapps.live.com/op/embed.aspx?src=${encodeURIComponent(sourceUrl)}`;
      return;
    }

    if (['txt', 'eml', 'csv', 'md'].includes(fmt)) {
      try {
        const response = await fetch(sourceUrl);
        if (!response.ok) {
          throw new Error(`Unable to load file (${response.status})`);
        }
        this.previewText = await response.text();
        this.previewType = 'text';
      } catch (error) {
        this.previewType = 'unsupported';
        this.previewError = `Text preview unavailable for ${asset.assetId}: ${String(error)}`;
      }
      return;
    }

    this.previewType = 'unsupported';
    this.previewError = `No browser preview configured for .${fmt} files.`;
  }

  employeeDisplay(employeeId: string): string {
    const emp = this.employees.find((x) => x.employeeId === employeeId);
    return emp ? `${emp.displayName} (${employeeId})` : employeeId;
  }

  private applyFilters(): void {
    const normalized = this.query.trim().toLowerCase();
    if (!normalized) {
      this.filteredAssets = [...this.assets];
    } else {
      const matchedEmployeeIds = new Set(
        this.employees
          .filter((emp) =>
            emp.employeeId.toLowerCase().includes(normalized) ||
            emp.displayName.toLowerCase().includes(normalized) ||
            emp.email.toLowerCase().includes(normalized)
          )
          .map((emp) => emp.employeeId)
      );

      this.filteredAssets = this.assets.filter((asset) =>
        matchedEmployeeIds.has(asset.employeeId) ||
        asset.assetId.toLowerCase().includes(normalized) ||
        asset.title.toLowerCase().includes(normalized) ||
        asset.format.toLowerCase().includes(normalized)
      );
    }

    this.page = 1;
    this.updateSuggestions();
  }

  private updateSuggestions(): void {
    const normalized = this.query.trim().toLowerCase();
    const employeeSuggestions = this.employees
      .map((emp) => `${emp.displayName} (${emp.employeeId})`)
      .filter((item) => !normalized || item.toLowerCase().includes(normalized));

    const assetSuggestions = this.assets
      .map((asset) => `${asset.assetId} • ${asset.title}`)
      .filter((item) => !normalized || item.toLowerCase().includes(normalized));

    this.suggestions = [...employeeSuggestions, ...assetSuggestions].slice(0, 12);
  }

  private async resolveAssetSourceUrl(asset: Asset): Promise<string> {
    const localPath = `/data/employees/${asset.storageRef.relativePath}`;

    // Always use local path when running on localhost (dev / demo mode)
    if (typeof window !== 'undefined' &&
        (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1')) {
      return localPath;
    }

    try {
      const config = await this.configService.loadConfig();
      const endpointTemplate = config.azure?.blobStorageEndpoint;
      if (!endpointTemplate || endpointTemplate.includes('{storageAccount}')) {
        return localPath;
      }
      return `${endpointTemplate}/${asset.storageRef.container}/${asset.storageRef.relativePath}`;
    } catch {
      return localPath;
    }
  }

  private async readJson<T>(url: string): Promise<T> {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Failed to load ${url}: ${response.status} ${response.statusText}`);
    }
    return response.json() as Promise<T>;
  }
}
