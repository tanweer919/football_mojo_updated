import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { GoogleGenAI } from '@google/genai';

export interface GroundedSource {
  title: string;
  uri: string;
}
export interface GroundedResult {
  text: string;
  sources: GroundedSource[];
  model: string;
}

/// Wrapper over the official Gemini SDK (@google/genai) with Google Search
/// grounding. The API key lives in the backend env (`GEMINI_API_KEY`); the
/// client never sees it.
@Injectable()
export class AiService {
  private readonly log = new Logger(AiService.name);
  private readonly client?: GoogleGenAI;
  private readonly model: string;

  constructor(cfg: ConfigService) {
    const apiKey = cfg.get<string>('GEMINI_API_KEY');
    this.model = cfg.get<string>('GEMINI_MODEL') ?? 'gemini-3.5-flash';
    this.client = apiKey ? new GoogleGenAI({ apiKey }) : undefined;
  }

  get enabled(): boolean {
    return !!this.client;
  }

  /// Generate text grounded with Google Search. Throws ServiceUnavailable when
  /// AI isn't configured or the upstream call fails.
  async generateGrounded(prompt: string): Promise<GroundedResult> {
    if (!this.client) throw new ServiceUnavailableException('ai_unavailable');
    try {
      const response = await this.client.models.generateContent({
        model: this.model,
        contents: prompt,
        // Google Search grounding — keeps form/injury/result lines current.
        config: { tools: [{ googleSearch: {} }] },
      });

      const text = (response.text ?? '').trim();
      if (!text) throw new ServiceUnavailableException('ai_empty_response');

      // Grounding citations (deduped, capped) — surfaced for trust.
      const chunks = response.candidates?.[0]?.groundingMetadata?.groundingChunks ?? [];
      const seen = new Set<string>();
      const sources: GroundedSource[] = [];
      for (const c of chunks) {
        const uri = c?.web?.uri;
        if (!uri || seen.has(uri)) continue;
        seen.add(uri);
        sources.push({ title: c?.web?.title ?? uri, uri });
        if (sources.length >= 6) break;
      }

      return { text, sources, model: this.model };
    } catch (e) {
      if (e instanceof ServiceUnavailableException) throw e;
      this.log.error(`gemini request failed: ${(e as Error).message}`);
      throw new ServiceUnavailableException('ai_request_failed');
    }
  }
}
