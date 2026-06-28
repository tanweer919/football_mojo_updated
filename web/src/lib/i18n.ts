/**
 * Lightweight i18n for the World Cup hub (no framework). 12 locale codes map to
 * 7 base-language dictionaries; locale variants (es-ES vs es-419, pt-BR vs
 * pt-PT, en-GB vs en-IN, fr-CA) reuse their base with a few keyword tweaks.
 * hreflang (in seo.ts) declares every code, so near-identical variants are not
 * treated as duplicate content. Translations are keyword-aware per the ASO
 * research; review by a native speaker before relying on them for ranking.
 */

export const LOCALES = [
  'en', 'en-GB', 'en-IN', 'fr', 'fr-CA', 'de', 'it',
  'pt-BR', 'pt-PT', 'es', 'es-419', 'es-ES', 'ar',
] as const;
export type Locale = (typeof LOCALES)[number];
export const DEFAULT_LOCALE: Locale = 'en';

/** Locales rendered under /[locale]/… (English lives at the root path). */
export const NON_DEFAULT_LOCALES = LOCALES.filter((l) => l !== DEFAULT_LOCALE);

export const isRtl = (l: Locale) => l === 'ar';

type BaseLang = 'en' | 'es' | 'pt' | 'fr' | 'de' | 'it' | 'ar';
function baseLang(l: Locale): BaseLang {
  if (l.startsWith('es')) return 'es';
  if (l.startsWith('pt')) return 'pt';
  if (l.startsWith('fr')) return 'fr';
  if (l === 'de') return 'de';
  if (l === 'it') return 'it';
  if (l === 'ar') return 'ar';
  return 'en';
}

export interface Dict {
  title: string;            // ≤60
  description: string;      // ≤155
  ogTitle: string;
  heroKicker: string;
  h1a: string;
  h1b: string;
  intro: string;
  fixturesHeading: string;
  allFixtures: string;
  latestResults: string;
  upcoming: string;
  standingsHeading: string;
  bracketHeading: string;
  bracketSoonTitle: string;
  bracketSoonNote: string;
  formatHeading: string;
  hostsHeading: string;
  ctaHeadline: string;
  faqHeading: string;
  faqs: { q: string; a: string }[];
}

const DICTS: Record<BaseLang, Dict> = {
  en: {
    title: 'World Cup 2026 Schedule, Fixtures & Live Scores',
    description: 'Full FIFA World Cup 2026 schedule, fixtures, live scores, group standings, knockout bracket and host cities — free, no betting. Get live goal alerts.',
    ogTitle: 'FIFA World Cup 2026 — Schedule, Fixtures, Live Scores & Bracket',
    heroKicker: 'FIFA World Cup 2026 · USA · Canada · Mexico',
    h1a: 'World Cup 2026', h1b: 'Schedule, Fixtures & Live Scores',
    intro: 'The complete FIFA World Cup 2026 hub — full match schedule, live scores, group standings, the knockout bracket and all 16 host cities. 48 teams, 104 matches. Follow every fixture and get instant goal alerts in the free FootballMojo app — no betting, family-safe.',
    fixturesHeading: 'Fixtures & results', allFixtures: 'All fixtures →', latestResults: 'Latest results', upcoming: 'Upcoming',
    standingsHeading: 'Group standings', bracketHeading: 'Knockout bracket',
    bracketSoonTitle: 'Round of 32 begins 28 June 2026',
    bracketSoonNote: 'The knockout bracket fills in once the group stage finishes. Follow it live — and predict the whole bracket — in the app.',
    formatHeading: 'Tournament format & key dates', hostsHeading: '16 host cities',
    ctaHeadline: 'Follow every World Cup 2026 match live', faqHeading: 'World Cup 2026 FAQ',
    faqs: [
      { q: 'When is the FIFA World Cup 2026?', a: 'The 2026 World Cup runs from 11 June to 19 July, hosted across the USA, Canada and Mexico — the first 48-team, 104-match edition.' },
      { q: 'Where can I watch World Cup 2026 live scores?', a: 'FootballMojo gives free live scores, fixtures, group tables and the full bracket, plus instant goal and full-time alerts — with no betting, no odds and no gambling.' },
      { q: 'Is FootballMojo free?', a: 'Yes. FootballMojo is 100% free on Google Play, family-safe, and contains no betting or gambling features.' },
    ],
  },
  es: {
    title: 'Mundial 2026: Calendario, Partidos y Resultados',
    description: 'Calendario completo del Mundial 2026, partidos, resultados en vivo, clasificación de grupos y cuadro final — gratis y sin apuestas. Alertas de goles.',
    ogTitle: 'Mundial 2026 — Calendario, Partidos, Resultados en Vivo y Cuadro',
    heroKicker: 'Copa Mundial 2026 · EE. UU. · Canadá · México',
    h1a: 'Mundial 2026', h1b: 'Calendario, Partidos y Resultados en Vivo',
    intro: 'El centro completo del Mundial 2026: calendario de partidos, resultados en vivo, clasificación de grupos, el cuadro de eliminatorias y las 16 sedes. 48 selecciones, 104 partidos. Sigue cada partido y recibe alertas de goles en la app gratuita FootballMojo — sin apuestas, apta para toda la familia.',
    fixturesHeading: 'Partidos y resultados', allFixtures: 'Ver todos →', latestResults: 'Últimos resultados', upcoming: 'Próximos',
    standingsHeading: 'Clasificación de grupos', bracketHeading: 'Cuadro de eliminatorias',
    bracketSoonTitle: 'Los dieciseisavos comienzan el 28 de junio de 2026',
    bracketSoonNote: 'El cuadro se completa al terminar la fase de grupos. Síguelo en vivo — y predice todo el cuadro — en la app.',
    formatHeading: 'Formato y fechas clave', hostsHeading: '16 sedes',
    ctaHeadline: 'Sigue en vivo cada partido del Mundial 2026', faqHeading: 'Preguntas frecuentes del Mundial 2026',
    faqs: [
      { q: '¿Cuándo es el Mundial 2026?', a: 'El Mundial 2026 se juega del 11 de junio al 19 de julio en EE. UU., Canadá y México — la primera edición con 48 selecciones y 104 partidos.' },
      { q: '¿Dónde ver los resultados en vivo del Mundial 2026?', a: 'FootballMojo ofrece resultados en vivo, partidos, tablas y el cuadro completo gratis, con alertas de goles — sin apuestas ni casas de apuestas.' },
      { q: '¿FootballMojo es gratis?', a: 'Sí. FootballMojo es 100% gratis en Google Play, apta para toda la familia y sin funciones de apuestas.' },
    ],
  },
  pt: {
    title: 'Copa do Mundo 2026: Jogos, Tabela e Resultados',
    description: 'Calendário completo da Copa do Mundo 2026, jogos, resultados ao vivo, classificação dos grupos e chave do mata-mata — grátis, sem apostas.',
    ogTitle: 'Copa do Mundo 2026 — Jogos, Resultados ao Vivo e Chave',
    heroKicker: 'Copa do Mundo 2026 · EUA · Canadá · México',
    h1a: 'Copa do Mundo 2026', h1b: 'Jogos, Tabela e Resultados ao Vivo',
    intro: 'O hub completo da Copa do Mundo 2026: calendário de jogos, resultados ao vivo, classificação dos grupos, a chave do mata-mata e as 16 sedes. 48 seleções, 104 jogos. Acompanhe cada jogo e receba alertas de gols no app gratuito FootballMojo — sem apostas, seguro para a família.',
    fixturesHeading: 'Jogos e resultados', allFixtures: 'Ver todos →', latestResults: 'Últimos resultados', upcoming: 'Próximos',
    standingsHeading: 'Classificação dos grupos', bracketHeading: 'Chave do mata-mata',
    bracketSoonTitle: 'A fase de 32 começa em 28 de junho de 2026',
    bracketSoonNote: 'A chave é preenchida quando a fase de grupos termina. Acompanhe ao vivo — e dê seu palpite na chave inteira — no app.',
    formatHeading: 'Formato e datas principais', hostsHeading: '16 cidades-sede',
    ctaHeadline: 'Acompanhe ao vivo cada jogo da Copa do Mundo 2026', faqHeading: 'Perguntas frequentes da Copa do Mundo 2026',
    faqs: [
      { q: 'Quando é a Copa do Mundo 2026?', a: 'A Copa de 2026 vai de 11 de junho a 19 de julho, nos EUA, Canadá e México — a primeira edição com 48 seleções e 104 jogos.' },
      { q: 'Onde ver os resultados ao vivo da Copa do Mundo 2026?', a: 'O FootballMojo oferece resultados ao vivo, jogos, tabelas e a chave completa de graça, com alertas de gols — sem apostas.' },
      { q: 'O FootballMojo é grátis?', a: 'Sim. O FootballMojo é 100% grátis no Google Play, seguro para a família e sem recursos de apostas.' },
    ],
  },
  fr: {
    title: 'Coupe du Monde 2026 : Calendrier, Matchs, Scores',
    description: 'Calendrier complet de la Coupe du Monde 2026, matchs, scores en direct, classement des groupes et tableau final — gratuit, sans paris.',
    ogTitle: 'Coupe du Monde 2026 — Calendrier, Matchs, Scores en Direct',
    heroKicker: 'Coupe du Monde 2026 · États-Unis · Canada · Mexique',
    h1a: 'Coupe du Monde 2026', h1b: 'Calendrier, Matchs & Scores en Direct',
    intro: "Le centre complet de la Coupe du Monde 2026 : calendrier des matchs, scores en direct, classement des groupes, le tableau à élimination directe et les 16 villes hôtes. 48 équipes, 104 matchs. Suivez chaque match et recevez des alertes de buts dans l'appli gratuite FootballMojo — sans paris, pour toute la famille.",
    fixturesHeading: 'Matchs et résultats', allFixtures: 'Tous les matchs →', latestResults: 'Derniers résultats', upcoming: 'À venir',
    standingsHeading: 'Classement des groupes', bracketHeading: 'Tableau final',
    bracketSoonTitle: 'Les seizièmes débutent le 28 juin 2026',
    bracketSoonNote: "Le tableau se remplit à la fin de la phase de groupes. Suivez-le en direct — et pronostiquez tout le tableau — dans l'appli.",
    formatHeading: 'Format et dates clés', hostsHeading: '16 villes hôtes',
    ctaHeadline: 'Suivez en direct chaque match de la Coupe du Monde 2026', faqHeading: 'FAQ Coupe du Monde 2026',
    faqs: [
      { q: 'Quand a lieu la Coupe du Monde 2026 ?', a: 'La Coupe du Monde 2026 se déroule du 11 juin au 19 juillet aux États-Unis, au Canada et au Mexique — la première édition à 48 équipes et 104 matchs.' },
      { q: 'Où voir les scores en direct de la Coupe du Monde 2026 ?', a: 'FootballMojo propose scores en direct, matchs, classements et le tableau complet gratuitement, avec alertes de buts — sans paris.' },
      { q: 'FootballMojo est-il gratuit ?', a: 'Oui. FootballMojo est 100 % gratuit sur Google Play, pour toute la famille, sans aucune fonction de paris.' },
    ],
  },
  de: {
    title: 'WM 2026: Spielplan, Spiele & Live-Ergebnisse',
    description: 'Kompletter WM-2026-Spielplan, Spiele, Live-Ergebnisse, Gruppen-Tabellen und K.-o.-Baum — kostenlos, ohne Wetten. Mit Tor-Benachrichtigungen.',
    ogTitle: 'WM 2026 — Spielplan, Spiele, Live-Ergebnisse & K.-o.-Runde',
    heroKicker: 'FIFA WM 2026 · USA · Kanada · Mexiko',
    h1a: 'WM 2026', h1b: 'Spielplan, Spiele & Live-Ergebnisse',
    intro: 'Der komplette WM-2026-Hub: Spielplan, Live-Ergebnisse, Gruppen-Tabellen, der K.-o.-Baum und alle 16 Austragungsorte. 48 Teams, 104 Spiele. Verfolge jedes Spiel und erhalte sofortige Tor-Benachrichtigungen in der kostenlosen FootballMojo-App — ohne Wetten, familienfreundlich.',
    fixturesHeading: 'Spiele & Ergebnisse', allFixtures: 'Alle Spiele →', latestResults: 'Letzte Ergebnisse', upcoming: 'Demnächst',
    standingsHeading: 'Gruppen-Tabellen', bracketHeading: 'K.-o.-Runde',
    bracketSoonTitle: 'Die Runde der letzten 32 beginnt am 28. Juni 2026',
    bracketSoonNote: 'Der K.-o.-Baum füllt sich nach der Gruppenphase. Verfolge ihn live — und tippe den ganzen Baum — in der App.',
    formatHeading: 'Format & wichtige Termine', hostsHeading: '16 Austragungsorte',
    ctaHeadline: 'Verfolge jedes WM-2026-Spiel live', faqHeading: 'WM 2026 – Häufige Fragen',
    faqs: [
      { q: 'Wann ist die WM 2026?', a: 'Die WM 2026 läuft vom 11. Juni bis 19. Juli in den USA, Kanada und Mexiko — die erste Ausgabe mit 48 Teams und 104 Spielen.' },
      { q: 'Wo gibt es Live-Ergebnisse zur WM 2026?', a: 'FootballMojo bietet kostenlose Live-Ergebnisse, Spiele, Tabellen und den kompletten K.-o.-Baum, mit Tor-Benachrichtigungen — ohne Wetten.' },
      { q: 'Ist FootballMojo kostenlos?', a: 'Ja. FootballMojo ist zu 100 % kostenlos bei Google Play, familienfreundlich und ohne Wett-Funktionen.' },
    ],
  },
  it: {
    title: 'Mondiale 2026: Calendario, Partite e Risultati',
    description: 'Calendario completo del Mondiale 2026, partite, risultati in diretta, classifica dei gironi e tabellone finale — gratis, senza scommesse.',
    ogTitle: 'Mondiale 2026 — Calendario, Partite, Risultati in Diretta',
    heroKicker: 'Mondiale FIFA 2026 · USA · Canada · Messico',
    h1a: 'Mondiale 2026', h1b: 'Calendario, Partite e Risultati in Diretta',
    intro: "L'hub completo del Mondiale 2026: calendario delle partite, risultati in diretta, classifica dei gironi, il tabellone a eliminazione e le 16 città ospitanti. 48 squadre, 104 partite. Segui ogni partita e ricevi notifiche dei gol nell'app gratuita FootballMojo — senza scommesse, adatta alle famiglie.",
    fixturesHeading: 'Partite e risultati', allFixtures: 'Tutte le partite →', latestResults: 'Ultimi risultati', upcoming: 'Prossime',
    standingsHeading: 'Classifica dei gironi', bracketHeading: 'Tabellone a eliminazione',
    bracketSoonTitle: 'I sedicesimi iniziano il 28 giugno 2026',
    bracketSoonNote: "Il tabellone si completa alla fine della fase a gironi. Seguilo in diretta — e pronostica tutto il tabellone — nell'app.",
    formatHeading: 'Formato e date chiave', hostsHeading: '16 città ospitanti',
    ctaHeadline: 'Segui in diretta ogni partita del Mondiale 2026', faqHeading: 'Mondiale 2026 — Domande frequenti',
    faqs: [
      { q: 'Quando si gioca il Mondiale 2026?', a: 'Il Mondiale 2026 si gioca dall’11 giugno al 19 luglio negli USA, in Canada e in Messico — la prima edizione con 48 squadre e 104 partite.' },
      { q: 'Dove vedere i risultati in diretta del Mondiale 2026?', a: 'FootballMojo offre risultati in diretta, partite, classifiche e il tabellone completo gratis, con notifiche dei gol — senza scommesse.' },
      { q: 'FootballMojo è gratis?', a: 'Sì. FootballMojo è gratis al 100% su Google Play, adatta alle famiglie e senza funzioni di scommesse.' },
    ],
  },
  ar: {
    title: 'كأس العالم 2026: المباريات والنتائج المباشرة',
    description: 'جدول كأس العالم 2026 الكامل، المباريات، النتائج المباشرة، ترتيب المجموعات وجدول الأدوار الإقصائية — مجانًا وبدون مراهنات. تنبيهات الأهداف.',
    ogTitle: 'كأس العالم 2026 — الجدول والمباريات والنتائج المباشرة',
    heroKicker: 'كأس العالم 2026 · الولايات المتحدة · كندا · المكسيك',
    h1a: 'كأس العالم 2026', h1b: 'الجدول والمباريات والنتائج المباشرة',
    intro: 'المركز الكامل لكأس العالم 2026: جدول المباريات، النتائج المباشرة، ترتيب المجموعات، جدول الأدوار الإقصائية و16 مدينة مستضيفة. 48 منتخبًا و104 مباريات. تابع كل مباراة واحصل على تنبيهات فورية للأهداف في تطبيق FootballMojo المجاني — بدون مراهنات ومناسب للعائلة.',
    fixturesHeading: 'المباريات والنتائج', allFixtures: 'كل المباريات →', latestResults: 'أحدث النتائج', upcoming: 'القادمة',
    standingsHeading: 'ترتيب المجموعات', bracketHeading: 'الأدوار الإقصائية',
    bracketSoonTitle: 'دور الـ32 يبدأ في 28 يونيو 2026',
    bracketSoonNote: 'يكتمل جدول الأدوار الإقصائية بعد انتهاء دور المجموعات. تابعه مباشرة — وتوقّع الجدول بالكامل — في التطبيق.',
    formatHeading: 'النظام والمواعيد المهمة', hostsHeading: '16 مدينة مستضيفة',
    ctaHeadline: 'تابع كل مباريات كأس العالم 2026 مباشرة', faqHeading: 'أسئلة شائعة عن كأس العالم 2026',
    faqs: [
      { q: 'متى يقام كأس العالم 2026؟', a: 'يقام كأس العالم 2026 من 11 يونيو إلى 19 يوليو في الولايات المتحدة وكندا والمكسيك — أول نسخة بـ48 منتخبًا و104 مباريات.' },
      { q: 'أين أشاهد النتائج المباشرة لكأس العالم 2026؟', a: 'يقدّم FootballMojo نتائج مباشرة ومباريات وجداول والأدوار الإقصائية كاملة مجانًا، مع تنبيهات الأهداف — بدون مراهنات.' },
      { q: 'هل FootballMojo مجاني؟', a: 'نعم. FootballMojo مجاني 100% على Google Play، مناسب للعائلة وبدون أي ميزات مراهنة.' },
    ],
  },
};

/** Tiny per-variant keyword tweaks (Latin-American vs Iberian Spanish, etc.). */
const VARIANT: Partial<Record<Locale, Partial<Dict>>> = {
  'es-ES': { title: 'Mundial 2026: Calendario, Partidos y Resultados en Directo', h1b: 'Calendario, Partidos y Resultados en Directo' },
  'pt-PT': { title: 'Mundial 2026: Jogos, Tabela e Resultados ao Vivo', h1a: 'Mundial 2026' },
};

export function getDict(locale: Locale): Dict {
  return { ...DICTS[baseLang(locale)], ...(VARIANT[locale] ?? {}) };
}
