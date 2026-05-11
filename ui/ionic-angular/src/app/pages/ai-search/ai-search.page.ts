import { Component } from '@angular/core';

type SearchResult = {
  documentId: string;
  employeeId: string;
  displayName: string;
  department: string;
  documentType: string;
  format: string;
  title: string;
  caption: string;
  score: number;
  rerankerScore: number;
  highlights: string;
  keyTopics: string[];
  aiSearchIndexed: boolean;
};

type FacetEntry = { value: string; count: number };

type SearchData = {
  indexName: string;
  indexStats: {
    documentCount: number;
    vectorDimensions: number;
    lastIndexerRun: string;
    indexerStatus: string;
    storageSize: string;
  };
  sampleQuery: {
    query: string;
    queryType: string;
    semanticConfiguration: string;
    top: number;
  };
  results: SearchResult[];
  facets: {
    department: FacetEntry[];
    format: FacetEntry[];
    documentType: FacetEntry[];
  };
  indexerConfig: {
    schedule: string;
    dataSourceType: string;
    targetIndexName: string;
    skills: { name: string; type: string; model?: string }[];
  };
};

const FORMAT_ICON: Record<string, string> = { pdf: '📄', pptx: '📊', xlsx: '📗', docx: '📝' };

@Component({
  selector: 'app-ai-search',
  templateUrl: './ai-search.page.html',
  styleUrls: ['./ai-search.page.scss']
})
export class AiSearchPage {
  description = 'Azure AI Search provides semantic and vector indexing over all employee knowledge assets — PDFs, presentations, spreadsheets, and documents extracted by Document Intelligence and ingested from Microsoft Graph.';

  searchData?: SearchData;
  selectedResult?: SearchResult;
  activeTab: 'results' | 'facets' | 'config' = 'results';
  loadError = '';

  get formatIcon() {
    return FORMAT_ICON;
  }

  scoreColor(score: number): string {
    if (score >= 0.95) return 'success';
    if (score >= 0.90) return 'warning';
    return 'medium';
  }

  selectResult(result: SearchResult): void {
    this.selectedResult = this.selectedResult?.documentId === result.documentId ? undefined : result;
  }

  setTab(tab: 'results' | 'facets' | 'config'): void {
    this.activeTab = tab;
  }

  constructor() {
    this.initialize().catch((err: unknown) => {
      this.loadError = `Unable to load AI Search results: ${err instanceof Error ? err.message : String(err)}`;
    });
  }

  async initialize(): Promise<void> {
    this.searchData = await this.readJson<SearchData>('/data/ai_search_results.json');
  }

  private async readJson<T>(url: string): Promise<T> {
    const response = await fetch(url);
    if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
    return response.json() as Promise<T>;
  }
}
