export interface EndpointConfig {
  azure: Record<string, string>;
  microsoftFabric: Record<string, string>;
  integration: Record<string, string>;
}

export class ConfigService {
  configPath = '/config/endpoints.json';
}
