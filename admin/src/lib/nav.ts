/**
 * Sidebar navigation registry — single source of truth for the admin shell.
 * Adding a new section means: (1) a row here, (2) a folder under
 * `app/(admin)/<segment>` with a `page.tsx`.
 */
export interface NavItem {
  label: string;
  href: string;
  /// SVG path data for a 24×24 lucide-style icon. We embed the d-attr
  /// inline rather than pulling lucide-react in — saves the dep + lets the
  /// icons inherit `currentColor` cleanly.
  icon: string;
}

export const NAV: NavItem[] = [
  {
    label: 'Dashboard',
    href: '/dashboard',
    icon: 'M3 12 12 3l9 9M5 10v10a1 1 0 0 0 1 1h3v-6h6v6h3a1 1 0 0 0 1-1V10',
  },
  {
    label: 'Players',
    href: '/players',
    icon: 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8ZM4 22c0-4.4 3.6-8 8-8s8 3.6 8 8',
  },
  {
    label: 'Cards',
    href: '/cards',
    icon: 'M3 7a2 2 0 0 1 2-2h11a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7Zm6-3v16M21 5v11a2 2 0 0 1-2 2',
  },
  {
    label: 'Teams',
    href: '/teams',
    icon: 'M12 2 4 6v6c0 4.5 3.4 8.7 8 10 4.6-1.3 8-5.5 8-10V6l-8-4Z',
  },
  {
    label: 'Users',
    href: '/users',
    icon: 'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8ZM22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75',
  },
];
