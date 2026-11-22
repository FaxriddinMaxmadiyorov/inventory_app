# Inventories

A web application for inventory management (office equipment, library books, HR documents and so on).
Users define inventories with their own ID format and custom fields; other users fill them with items.

Ruby on Rails 8, PostgreSQL, Bootstrap 5.

## Running locally

Requirements: Ruby 3.2+, PostgreSQL 13+.

```bash
bundle install
cp .env.example .env        # fill in OAuth / Cloudinary keys when you have them
bin/rails db:prepare        # creates the database, runs migrations and seeds
bin/rails server
```

Open http://localhost:3000. In development the seeds create an administrator:
`admin@example.com` / `password`, plus a demo inventory.

Tests: `bin/rails test`.

### Configuration (`.env`)

| Variable | Purpose |
| --- | --- |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | Google sign-in. Redirect URI: `/users/auth/google_oauth2/callback` |
| `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET` | GitHub sign-in. Callback URL: `/users/auth/github/callback` |
| `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_UPLOAD_PRESET` | Image upload. The preset must be *unsigned* |
| `RESEND_API_KEY`, `MAILER_FROM` | Confirmation e-mails through the Resend API. `MAILER_FROM` must be on a domain verified in Resend |
| `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD` | Alternative to Resend: plain SMTP. With neither configured the letters are only written to the log |
| `APP_HOST` | Host used in e-mail links |
| `DB_HOST`, `DB_USER`, `DB_PASSWORD` | Database connection (or `DATABASE_URL`) |

In production also set `SECRET_KEY_BASE` (`bin/rails secret`), `DATABASE_URL`, `RAILS_ENV=production`,
and run `bin/rails assets:precompile db:migrate db:seed` on deploy.

Categories are added directly in the database (`categories` table); the seeds create the initial ones.

## How it is built

### Data model

* `inventories` - title, description, category, image URL, `is_public`, `lock_version`, and the settings of the
  custom field slots. There are three slots for each field type, stored as plain columns:
  `custom_string1_state`, `custom_string1_name`, `custom_string1_description`, `custom_string1_show`,
  `custom_string1_position`, ... The types are `string`, `text`, `number`, `link`, `bool` and `select`.
* `items` - `custom_id`, `sequence`, `lock_version` and one column per slot: `custom_string1..3`, `custom_text1..3`,
  `custom_number1..3`, `custom_link1..3`, `custom_bool1..3`, `custom_select1..3`.
  Nothing is stored as JSON and no tables are created at run time, so all items of an inventory are always compatible
  and aggregates are ordinary SQL. Removing a field only switches its slot off; item data is never rewritten.
* `id_elements` - the ordered parts of an inventory's custom ID format.
* `tags`, `inventory_tags`, `inventory_accesses`, `posts`, `likes`, `categories`, `users`.

`CustomField` (app/models/custom_field.rb) is a small wrapper that presents a slot as an object.

### Custom IDs

`CustomId` (app/models/custom_id.rb) generates an ID from the elements and builds a regular expression to validate
IDs edited by hand. Supported elements: fixed text, 20-bit / 32-bit / 6-digit / 9-digit random numbers, GUID,
date/time and sequence. The unique index on `(inventory_id, custom_id)` guarantees uniqueness inside an inventory;
when two users collide, the database rejects the second insert and that user edits the ID manually.

### Optimistic locking

Inventories and items have a `lock_version` column (ActiveRecord optimistic locking).

* The inventory page auto-saves every 8 seconds. Each request carries the version the page has; the server answers
  with the next version or with `409 Conflict`, after which the page stops saving and offers a reload.
* The item form carries the version in a hidden field; a stale save shows a message instead of overwriting.
* Bulk deletes send `id:lock_version` pairs, so records changed by somebody else in the meantime are not deleted.

### Other notes

* Full-text search uses PostgreSQL `tsvector` with GIN indexes on `inventories.search_text` and `items.search_text`.
* Tables never have buttons in rows: rows are selected with checkboxes and the actions are in a toolbar.
* The discussion tab polls for new posts every 3 seconds.
* Images are uploaded from the browser straight to Cloudinary (upload widget); only the URL is saved.
* Authentication: Devise with e-mail confirmation, plus Google and GitHub through OmniAuth.
* Two languages (English, Uzbek) and two themes (light, dark); the choice is saved in the user profile
  (in a cookie for guests).
* Ready-made components: Bootstrap, Bootstrap Icons, SortableJS (drag and drop), Tom Select (tags and user
  autocomplete), EasyMDE (Markdown editor), Redcarpet (Markdown rendering), Kaminari (pagination),
  Ransack (sorting and filtering of tables), caxlsx (Excel export), Cloudinary upload widget.
