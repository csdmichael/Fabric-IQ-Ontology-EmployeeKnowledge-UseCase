import { Component } from '@angular/core';

@Component({
  selector: 'app-ingestion-flow',
  templateUrl: './ingestion-flow.page.html',
  styleUrls: ['./ingestion-flow.page.scss']
})
export class IngestionFlowPage {
  description = 'Shows Fabric pipeline stages, document intelligence classification, and OneLake load.';
}
