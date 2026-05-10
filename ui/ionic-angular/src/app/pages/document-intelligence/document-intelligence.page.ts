import { Component } from '@angular/core';

type DocIntelResult = {
  documentId: string;
  employeeId: string;
  format: string;
  originalFileName: string;
  documentType: string;
  classification: string;
  extractedAt: string;
  modelUsed: string;
  documentConfidence: number;
  pageCount: number;
  extractedFields: {
    title: string;
    author: string;
    date: string;
    department: string;
    keyTopics: string[];
    [key: string]: unknown;
  };
  tables: {
    tableId: number;
    rowCount: number;
    columnCount: number;
    headers: string[];
    rows: string[][];
  }[];
  keyValuePairs: { key: string; value: string }[];
  paragraphs: string[];
  aiSearchIndexed: boolean;
  blobPath: string;
};

const FORMAT_ICON: Record<string, string> = {
  pdf: '📄',
  pptx: '📊',
  xlsx: '📗',
  docx: '📝',
};

@Component({
  selector: 'app-document-intelligence',
  templateUrl: './document-intelligence.page.html',
  styleUrls: ['./document-intelligence.page.scss']
})
export class DocumentIntelligencePage {
  description = 'Azure AI Document Intelligence extracts structured JSON from employee documents — PDFs, PowerPoint decks, Excel spreadsheets, and Word documents. Results are stored in Cosmos DB and indexed in Azure AI Search.';

  results: DocIntelResult[] = [];
  filtered: DocIntelResult[] = [];
  selected?: DocIntelResult;

  query = '';
  formatFilter = '';
  loadError = '';

  get formats(): string[] {
    const seen = new Set<string>();
    this.results.forEach((r) => seen.add(r.format));
    return Array.from(seen).sort();
  }

  get formatIcon() {
    return FORMAT_ICON;
  }

  confidenceColor(score: number): string {
    if (score >= 0.95) return 'success';
    if (score >= 0.85) return 'warning';
    return 'danger';
  }

  countByFormat(format: string): number {
    return this.results.filter((r) => r.format === format).length;
  }

  countIndexed(): number {
    return this.results.filter((r) => r.aiSearchIndexed).length;
  }

  constructor() {
    this.initialize().catch((err: unknown) => {
      this.loadError = `Unable to load Document Intelligence results: ${err instanceof Error ? err.message : String(err)}`;
    });
  }

  async initialize(): Promise<void> {
    const data = await this.readJson<DocIntelResult[]>('/data/document_intelligence_results.json');
    this.results = data;
    this.filtered = [...data];
  }

  onQueryInput(value: string): void {
    this.query = value;
    this.applyFilters();
  }

  onFormatFilter(value: string): void {
    this.formatFilter = value;
    this.applyFilters();
  }

  clearFilters(): void {
    this.query = '';
    this.formatFilter = '';
    this.filtered = [...this.results];
    this.selected = undefined;
  }

  selectResult(result: DocIntelResult): void {
    this.selected = this.selected?.documentId === result.documentId ? undefined : result;
  }

  private applyFilters(): void {
    const q = this.query.trim().toLowerCase();
    this.filtered = this.results.filter((r) => {
      const matchesFormat = !this.formatFilter || r.format === this.formatFilter;
      const matchesQuery = !q ||
        r.documentId.toLowerCase().includes(q) ||
        r.employeeId.toLowerCase().includes(q) ||
        r.originalFileName.toLowerCase().includes(q) ||
        r.documentType.toLowerCase().includes(q) ||
        r.extractedFields.title.toLowerCase().includes(q) ||
        r.extractedFields.department.toLowerCase().includes(q) ||
        r.extractedFields.keyTopics.some((t) => t.toLowerCase().includes(q));
      return matchesFormat && matchesQuery;
    });
    this.selected = undefined;
  }

  private async readJson<T>(url: string): Promise<T> {
    const response = await fetch(url);
    if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
    return response.json() as Promise<T>;
  }
}
