# GitHub Recommendation

Use GitHub for:
- Hosting the app through GitHub Pages
- Keeping version history of the HTML, SQL, configuration template, manifest, and service worker
- Rolling back a bad app-code update

Do not use the repository as the live sales/inventory database and do not commit:
- Family email or password
- Supabase service-role key
- Database password
- Downloaded JSON/CSV business backups
- Private customer information

The public Supabase anon/publishable key is designed for client apps, but it is safe only because `supabase_setup.sql` enables Row Level Security and requires authenticated ownership of every row.
