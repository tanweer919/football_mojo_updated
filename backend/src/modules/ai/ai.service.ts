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
    // Grounded flash model. Override with GEMINI_MODEL if Google moves it.
    this.model = cfg.get<string>('GEMINI_MODEL') ?? 'gemini-3.5-flash';
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
      // Grounding tool MUST be camelCase `googleSearch` for gemini 2.5/3.x — the
      // snake_case form is silently ignored, so nothing was actually grounded.
      tools: [{ googleSearch: {} }],
      generationConfig: {
        temperature: 0.6,
        maxOutputTokens: 1200,
        // gemini-3.5-flash has "thinking" on by default. Its reasoning tokens
        // ate the whole output budget (truncating the answer) and leaked into
        // the text ("Total so far: 144 words…"). Turn it off — we want the
        // finished answer directly, not the scratchpad.
        thinkingConfig: { thinkingBudget: 0 },
      },
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
      .filter((p: any) => !p?.thought) // never surface reasoning/thought parts
      .map((p: any) => p?.text ?? '')
      .join('')
      .trim();
    if (!text) throw new ServiceUnavailableException('ai_empty_response');

    // Diagnostic: confirm grounding actually fired. If `grounded=0` the model
    // answered from training data (stale / generic), not live Search — that's
    // the "dumb response" signature. `queries` shows what it searched for.
    const meta = cand?.groundingMetadata;
    this.log.log(
      `gemini model=${this.model} grounded=${meta?.groundingChunks?.length ?? 0} ` +
        `queries=${JSON.stringify(meta?.webSearchQueries ?? [])}`,
    );

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
