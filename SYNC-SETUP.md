# Setting up cloud sync (Supabase), about 10 minutes

Cloud sync keeps every phone, tablet and office PC up to date whenever it has signal. Logging still works offline: changes wait on the device and are sent the next time it connects.

## 1. Create the database (once, by an admin)
1. Create a free account at supabase.com and start a **New project**. Pick the Canada (Central) region if your data should stay in Canada.
2. Open **SQL Editor**, then **New query**. Paste in all of `supabase.sql` from this folder and click **Run**. It's safe to run again later, and you should run it again when you update FieldLog, because this version adds the template and admin tables.
3. Under **Authentication**, turn off **Allow new users to sign up**, so that only people you add can get in.
4. Under **Authentication → Users**, use **Add user** to create an account (email and password) for each logger and office user, with auto-confirm on.

Every user you add can see and edit all FieldLog projects in this Supabase project. Use one Supabase project per company or team.

5. Choose who can change the company template (pick lists, log layout, field rules, graphics). In the SQL Editor, run:
   `insert into public.fieldlog_admins (email) values ('you@yourcompany.ca') on conflict do nothing;`
   Add one line for each admin. Everyone else sees the template read-only. The server rejects template changes from anyone not listed.

## 2. Connect the app
1. In Supabase, open **Project Settings → API** (or **API Keys**). Copy the **Project URL** and the **publishable / anon** key. Never use the secret / service_role key.
2. Choose one of these:
   - **Recommended:** before uploading the app, open `fieldlog-config.json`, paste in the two values and upload it with the rest of the app. Users then only need to sign in.
   - **Or** on each device, go to **Settings → Cloud sync**, enter the URL and key, then tap **Save server**.
3. Each person signs in under **Settings → Cloud sync** with their email and password.

When a device signs in for the first time, it uploads everything it already holds and downloads everyone else's work.

## How conflicts are handled
- Each hole syncs as one record. If two people edit the same hole, the most recent edit wins.
- A deleted hole is deleted everywhere, and a later edit can't bring it back.
- If a device's clock was wrong and it sends an older version, the server keeps its newer copy and corrects the device.
- Deleting a whole project only removes it from that device. Other devices and the server keep it.

## Changing the server later
Sync is written so another backend (your own server, Azure, etc.) can be added. To switch, enter the new server details and sign in. Every device then uploads its full copy to the new server, so nothing is lost. The `.json` export / import still works as a backup at any time.
