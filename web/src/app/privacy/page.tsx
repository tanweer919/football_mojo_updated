import type { Metadata } from 'next';
import type { ReactNode } from 'react';
import { SITE } from '@/lib/site';

export const metadata: Metadata = {
  title: 'Privacy Policy',
  description: `How ${SITE.name} collects, uses and protects your data — including advertising (Google AdMob), analytics, GDPR and CCPA rights.`,
  alternates: { canonical: '/privacy' },
  openGraph: {
    title: `Privacy Policy · ${SITE.name}`,
    description: `How ${SITE.name} handles your data, advertising and privacy rights.`,
    url: `${SITE.url}/privacy`,
  },
};

function H2({ id, children }: { id: string; children: ReactNode }) {
  return (
    <h2 id={id} className="mt-12 scroll-mt-24 font-display text-2xl font-extrabold tracking-tight text-fg">
      {children}
    </h2>
  );
}
function H3({ children }: { children: ReactNode }) {
  return <h3 className="mt-7 text-lg font-bold text-fg">{children}</h3>;
}
function P({ children }: { children: ReactNode }) {
  return <p className="mt-4 leading-relaxed text-fg-soft">{children}</p>;
}
function UL({ children }: { children: ReactNode }) {
  return <ul className="mt-4 space-y-2 pl-1 text-fg-soft">{children}</ul>;
}
function LI({ children }: { children: ReactNode }) {
  return (
    <li className="flex gap-3 leading-relaxed">
      <span className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-gold/70" />
      <span>{children}</span>
    </li>
  );
}
function A({ href, children }: { href: string; children: ReactNode }) {
  return (
    <a href={href} target="_blank" rel="noopener noreferrer" className="text-gold underline-offset-2 hover:underline">
      {children}
    </a>
  );
}

export default function PrivacyPage() {
  return (
    <article className="container-x py-16 sm:py-20">
      <div className="mx-auto max-w-3xl">
        <span className="eyebrow">Legal</span>
        <h1 className="mt-4 font-display text-4xl font-extrabold tracking-tight sm:text-5xl">Privacy Policy</h1>
        <p className="mt-4 text-sm text-fg-muted">Last updated: {SITE.lastUpdated}</p>

        <P>
          This Privacy Policy explains how {SITE.name} (“we”, “us”, “our”) collects, uses, shares and
          protects information when you use the {SITE.name} mobile app and this website (together, the
          “Services”). By using the Services you agree to the practices described here. If you do not
          agree, please do not use the Services.
        </P>

        {/* 1 */}
        <H2 id="who-we-are">1. Who we are</H2>
        <P>
          {SITE.name} is a football companion app for the FIFA World Cup 2026 (live scores, brackets,
          predictions, fantasy and collectible cards). For privacy questions or to exercise your
          rights, contact us at{' '}
          <A href={`mailto:${SITE.privacyEmail}`}>{SITE.privacyEmail}</A>. For the purposes of the EU/UK
          GDPR, we act as the data controller for personal data processed through the Services.
        </P>

        {/* 2 */}
        <H2 id="information-we-collect">2. Information we collect</H2>
        <H3>Information you provide</H3>
        <UL>
          <LI>
            <strong>Account information.</strong> You can use {SITE.name} anonymously, or sign in with
            Google. If you sign in, we receive your name, email address and profile photo from your
            Google account via Firebase Authentication.
          </LI>
          <LI>
            <strong>Gameplay data.</strong> Your score predictions, World Cup bracket picks, fantasy
            lineups, collectible card inventory, followed teams, league memberships and in-app
            achievements.
          </LI>
          <LI>
            <strong>Communications.</strong> Any messages you send us (e.g. support emails).
          </LI>
        </UL>

        <H3>Information collected automatically</H3>
        <UL>
          <LI>
            <strong>Device &amp; technical data.</strong> Device model, operating system version, app
            version, language, time zone, and a generated installation/account identifier.
          </LI>
          <LI>
            <strong>Advertising identifiers.</strong> Where permitted, the Google Advertising ID
            (Android) used to serve and measure ads (see “Advertising” below).
          </LI>
          <LI>
            <strong>Usage &amp; diagnostics.</strong> Screens viewed, features used, interactions,
            approximate region (from IP), crash logs and performance data.
          </LI>
        </UL>

        {/* 3 */}
        <H2 id="how-we-use">3. How we use information</H2>
        <UL>
          <LI>Provide and operate the Services — accounts, scores, brackets, fantasy, leaderboards and cards.</LI>
          <LI>Sync your progress across sessions and devices and surface relevant teams and matches.</LI>
          <LI>Show advertising and measure its performance (see “Advertising”).</LI>
          <LI>Understand usage, fix bugs, and improve performance and features.</LI>
          <LI>Send service and notification messages you have opted into (e.g. match alerts).</LI>
          <LI>Protect the Services against fraud, abuse and security incidents, and comply with law.</LI>
        </UL>

        {/* 4 */}
        <H2 id="advertising">4. Advertising &amp; Google AdMob</H2>
        <P>
          {SITE.name} is free and supported by advertising. We use{' '}
          <strong>Google AdMob</strong> (provided by Google) to serve banner, interstitial and rewarded
          ads. To deliver, cap and measure ads, AdMob and its partners may process your device’s
          advertising identifier, IP-derived approximate location, and ad-interaction events.
        </P>
        <P>
          Ads may be <strong>personalized</strong> (based on your interests) or{' '}
          <strong>non-personalized</strong> (based only on coarse, contextual signals). In the European
          Economic Area, the United Kingdom and Switzerland, we use Google’s{' '}
          <strong>User Messaging Platform (UMP)</strong> consent form to ask for your choice before
          serving personalized ads; if you decline, you will receive non-personalized ads.
        </P>
        <UL>
          <LI>
            Learn how Google uses data from apps that use its services:{' '}
            <A href="https://policies.google.com/technologies/partner-sites">
              google.com/technologies/partner-sites
            </A>
            .
          </LI>
          <LI>
            Google’s Privacy Policy:{' '}
            <A href="https://policies.google.com/privacy">policies.google.com/privacy</A>.
          </LI>
          <LI>
            Manage Google ad personalization:{' '}
            <A href="https://adssettings.google.com">adssettings.google.com</A>.
          </LI>
          <LI>
            On Android you can reset or delete your Advertising ID, or opt out of ad personalization,
            in <strong>Settings → Privacy → Ads</strong>.
          </LI>
        </UL>
        <P>
          We do <strong>not</strong> use ads or tracking to target children, and {SITE.name} contains no
          gambling or betting.
        </P>

        {/* 5 */}
        <H2 id="analytics">5. Analytics &amp; diagnostics</H2>
        <UL>
          <LI>
            <strong>Microsoft Clarity.</strong> We use Microsoft Clarity to understand product usage
            through metrics and aggregated interaction data, which helps us improve the Services. See
            the <A href="https://privacy.microsoft.com/privacystatement">Microsoft Privacy Statement</A>.
          </LI>
          <LI>
            <strong>Google / Firebase.</strong> We use Firebase (Authentication, Cloud Messaging and
            related services) by Google. See{' '}
            <A href="https://firebase.google.com/support/privacy">Firebase privacy &amp; security</A>.
          </LI>
        </UL>

        {/* 6 */}
        <H2 id="legal-bases">6. Legal bases for processing (EEA/UK)</H2>
        <P>Where the GDPR or UK GDPR applies, we rely on the following legal bases:</P>
        <UL>
          <LI><strong>Performance of a contract</strong> — to provide the Services you request (accounts, gameplay, leaderboards).</LI>
          <LI><strong>Consent</strong> — for personalized advertising and any non-essential analytics where consent is required; you may withdraw consent at any time.</LI>
          <LI><strong>Legitimate interests</strong> — to secure, maintain and improve the Services and serve non-personalized ads, balanced against your rights.</LI>
          <LI><strong>Legal obligation</strong> — to comply with applicable laws and lawful requests.</LI>
        </UL>

        {/* 7 */}
        <H2 id="sharing">7. How we share information</H2>
        <P>We do not sell your personal information. We share data only with:</P>
        <UL>
          <LI><strong>Service providers</strong> that operate the Services on our behalf — including Google (Firebase, AdMob), Microsoft (Clarity), our deep-linking provider, push-notification and hosting providers — under contracts that limit their use of the data.</LI>
          <LI><strong>Other users</strong>, only where you choose to participate — e.g. your display name, photo and score appear on leaderboards and in leagues you join.</LI>
          <LI><strong>Legal &amp; safety</strong> — where required by law, or to protect our rights, users and the Services.</LI>
          <LI><strong>Business transfers</strong> — in connection with a merger, acquisition or sale of assets, subject to this Policy.</LI>
        </UL>

        {/* 8 */}
        <H2 id="transfers">8. International data transfers</H2>
        <P>
          Our providers may process data in countries other than yours, including the United States.
          Where required, such transfers are protected by appropriate safeguards such as the European
          Commission’s Standard Contractual Clauses.
        </P>

        {/* 9 */}
        <H2 id="retention">9. Data retention</H2>
        <P>
          We keep personal data only as long as needed to provide the Services and for the purposes in
          this Policy, then delete or anonymize it. If you delete your account, we delete or anonymize
          the personal data associated with it, except where we must retain certain information to
          comply with legal obligations or resolve disputes.
        </P>

        {/* 10 */}
        <H2 id="your-rights">10. Your privacy rights</H2>
        <H3>EEA / UK (GDPR)</H3>
        <P>Subject to applicable law, you may request to:</P>
        <UL>
          <LI>Access the personal data we hold about you.</LI>
          <LI>Rectify inaccurate data, or erase your data (“right to be forgotten”).</LI>
          <LI>Restrict or object to certain processing, including direct marketing and profiling.</LI>
          <LI>Receive your data in a portable format.</LI>
          <LI>Withdraw consent at any time (this does not affect prior processing).</LI>
          <LI>Lodge a complaint with your local data protection supervisory authority.</LI>
        </UL>
        <H3>California (CCPA/CPRA)</H3>
        <P>
          California residents have the right to know, access, correct and delete personal information,
          and to opt out of its “sale” or “sharing”. We do not sell or share personal information as
          those terms are defined under California law, and we will not discriminate against you for
          exercising your rights.
        </P>
        <P>
          To exercise any of these rights, email{' '}
          <A href={`mailto:${SITE.privacyEmail}`}>{SITE.privacyEmail}</A>. We will verify and respond
          as required by applicable law.
        </P>

        {/* 11 */}
        <H2 id="children">11. Children’s privacy</H2>
        <P>
          The Services are intended for a general audience and are not directed to children under 13
          (or under 16 in the EEA/UK). We do not knowingly collect personal data from children. If you
          believe a child has provided us with personal data, contact us and we will delete it.
        </P>

        {/* 12 */}
        <H2 id="security">12. Security</H2>
        <P>
          We use technical and organizational measures designed to protect your information. No method
          of transmission or storage is completely secure, so we cannot guarantee absolute security.
        </P>

        {/* 13 */}
        <H2 id="cookies">13. Cookies &amp; local storage</H2>
        <P>
          This website uses only essential cookies/local storage needed for it to function. The app
          stores limited data on your device (e.g. sign-in state and preferences). Advertising and
          analytics partners may set their own identifiers as described above; you can control these
          through your device settings and the consent choices we present.
        </P>

        {/* 14 */}
        <H2 id="changes">14. Changes to this Policy</H2>
        <P>
          We may update this Policy from time to time. We will revise the “Last updated” date above and,
          for material changes, provide a more prominent notice. Your continued use of the Services
          after an update means you accept the revised Policy.
        </P>

        {/* 15 */}
        <H2 id="contact">15. Contact us</H2>
        <P>
          Questions about this Policy or your data? Email{' '}
          <A href={`mailto:${SITE.privacyEmail}`}>{SITE.privacyEmail}</A> or{' '}
          <A href={`mailto:${SITE.contactEmail}`}>{SITE.contactEmail}</A>.
        </P>
      </div>
    </article>
  );
}
