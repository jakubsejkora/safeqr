export interface EngineVerdict {
  kind: string;
  title: string;
  summary: string;
  facts: { id: string; label: string; value: string }[];
  score: number;
  level: string;
  findings: { id: string; severity: string; title: string; detail: string }[];
  consequences: string[];
  limitations: string[];
  containsSecrets: boolean;
}

export interface CodeVerdicts {
  primary: EngineVerdict;
  secondary: EngineVerdict | null;
}

export interface GalleryVerdicts {
  payload: string;
  secondPayload: string | null;
  cs: CodeVerdicts;
  en: CodeVerdicts;
}
