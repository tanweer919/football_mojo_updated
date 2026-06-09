import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export interface GroundedSource {
  title: string;
  uri: string;
}
export interface GroundedResult {
  text: string;
  sources: GroundedSource[];
  model: string;
}

/// Gemini wrapper with Google Search grounding, via the REST API and the
/// built-in `fetch` — NO SDK dependency on purpose. The official @google/genai
/// package is ESM-first and crash-loops this CommonJS NestJS app at boot
/// (ERR_REQUIRE_ESM), which takes down the whole API. The key lives in the
/// backend env (`GEMINI_API_KEY`); the client never sees it.
@Injectable()
export class AiService {
  private readonly log = new Logger(AiService.name);
  private readonly apiKey?: string;
  private readonly model: string;

  constructor(cfg: ConfigService) {
    this.apiKey = cfg.get<string>('GEMINI_API_KEY');
    // gemini-2.0-flash was the original, well-grounded model that produced the
    // accurate previews; 3.5-flash regressed quality here. Override with
    // GEMINI_MODEL if you want a different one.
    this.model = cfg.get<string>('GEMINI_MODEL') ?? 'gemini-2.0-flash';
  }

  get enabled(): boolean {
    return !!this.apiKey;
  }

  /// Generate text grounded with Google Search. Throws ServiceUnavailable when
  /// AI isn't configured or the upstream call fails.
  async generateGrounded(prompt: string): Promise<GroundedResult> {
    if (!this.apiKey) throw new ServiceUnavailableException('ai_unavailable');

    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/${this.model}:generateContent?key=${this.apiKey}`;
    const body = {
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      // Google Search grounding — keeps form/injury/result lines current.
      tools: [{ google_search: {} }],
      generationConfig: { temperature: 0.6, maxOutputTokens: 900 },
    };

    let data: any;
    try {
      const res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(25_000),
      });
      if (!res.ok) {
        const t = await res.text().catch(() => '');
        this.log.error(`gemini ${res.status}: ${t.slice(0, 300)}`);
        throw new ServiceUnavailableException('ai_request_failed');
      }
      data = await res.json();
    } catch (e) {
      if (e instanceof ServiceUnavailableException) throw e;
      this.log.error(`gemini request failed: ${(e as Error).message}`);
      throw new ServiceUnavailableException('ai_request_failed');
    }

    const cand = data?.candidates?.[0];
    const text: string = (cand?.content?.parts ?? [])
      .map((p: any) => p?.text ?? '')
      .join('')
      .trim();
    if (!text) throw new ServiceUnavailableException('ai_empty_response');

    // Grounding citations (deduped, capped) — surfaced for trust.
    const chunks: any[] = cand?.groundingMetadata?.groundingChunks ?? [];
    const seen = new Set<string>();
    const sources: GroundedSource[] = [];
    for (const c of chunks) {
      const uri: string | undefined = c?.web?.uri;
      if (!uri || seen.has(uri)) continue;
      seen.add(uri);
      sources.push({ title: c?.web?.title ?? uri, uri });
      if (sources.length >= 6) break;
    }

    return { text, sources, model: this.model };
  }
}
