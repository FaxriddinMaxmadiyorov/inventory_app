require "test_helper"

class AppTest < ActionDispatch::IntegrationTest
  setup do
    Category.create!(name: "Equipment")
    @owner = create_user("Owner")
    @writer = create_user("Writer")
    @stranger = create_user("Stranger")
    @admin = create_user("Admin", admin: true)
    @inventory = create_inventory(@owner, description: "**Office** laptops")
    @inventory.apply_fields([{ kind: "string", slot: 1, name: "Model", show: true }, { kind: "number", slot: 2, name: "Price", show: true },
                             { kind: "text", slot: 1, name: "Notes", show: false }, { kind: "link", slot: 1, name: "Photo", show: false },
                             { kind: "bool", slot: 1, name: "In use", show: true }, { kind: "select", slot: 1, name: "Type", options: "A\nB" }])
    @inventory.tag_list = %w[office laptops]
    @inventory.save!
    @inventory.inventory_accesses.create!(user: @writer)
    @item = @inventory.items.create!(custom_string1: "Thinkpad", custom_number2: 900, custom_link1: "https://example.com/p.jpg", user: @owner)
  end

  def autosave(payload, version: @inventory.reload.lock_version)
    patch autosave_inventory_path(@inventory), params: payload.merge(lock_version: version), as: :json
  end

  # --- guests ---------------------------------------------------------------

  test "guests can read everything but change nothing" do
    [root_path, search_path(q: "thinkpad"), search_path(tag: "office"), inventory_path(@inventory),
     inventory_path(@inventory, tab: "chat"), inventory_path(@inventory, tab: "stats"),
     inventory_item_path(@inventory, @item), user_path(@owner), new_user_session_path, new_user_registration_path,
     new_user_password_path, new_user_confirmation_path].each do |path|
      get path
      assert_response :success, path
      assert_translated
    end

    get inventory_path(@inventory, tab: "settings")
    assert_select "[data-autosave]", 0

    post inventories_path
    assert_redirected_to new_user_session_path
    get new_inventory_item_path(@inventory)
    assert_redirected_to new_user_session_path
    post inventory_item_like_path(@inventory, @item)
    assert_redirected_to new_user_session_path
    post inventory_posts_path(@inventory), params: { body: "hi" }, as: :json
    assert_response :unauthorized
    get admin_users_path
    assert_redirected_to new_user_session_path
  end

  test "pages render in Uzbek and the choice is remembered" do
    patch preferences_path(locale: "uz", theme: "dark")
    get root_path
    assert_select "html[lang=uz][data-bs-theme=dark]"
    assert_translated

    sign_in @owner
    patch preferences_path(locale: "uz", theme: "dark")
    assert_equal %w[uz dark], [@owner.reload.locale, @owner.theme]
    InventoriesController::TABS.each do |tab|
      get inventory_path(@inventory, tab: tab)
      assert_response :success, tab
      assert_translated
    end
    [inventory_item_path(@inventory, @item), new_inventory_item_path(@inventory), user_path(@owner), edit_user_registration_path].each do |path|
      get path
      assert_response :success
      assert_translated
    end
  end

  test "search finds inventories and items" do
    get search_path(q: "think")
    assert_select "a[href=?]", inventory_item_path(@inventory, @item)
    get search_path(q: "office")
    assert_select "a[href=?]", inventory_path(@inventory)
    get search_path(tag: "laptops")
    assert_select "a[href=?]", inventory_path(@inventory)
    get tags_path(q: "of"), as: :json
    assert_equal ["office"], json
  end

  # --- inventory owner --------------------------------------------------------

  test "owner creates an inventory and edits it with auto-save" do
    sign_in @owner
    post inventories_path
    @inventory = @owner.inventories.order(:id).last
    assert_redirected_to inventory_path(@inventory, tab: "settings")

    %w[settings custom_id fields access export].each do |tab|
      get inventory_path(@inventory, tab: tab)
      assert_response :success
      assert_select "[data-autosave]", tab == "export" ? 0 : 1
      assert_translated
    end

    autosave({ inventory: { title: "Books", description: "Library", category_id: Category.first.id, is_public: true,
                            image_url: "https://res.cloudinary.com/demo/a.jpg", tags: %w[Books paper] } }, version: 0)
    assert_response :success
    assert_equal 1, json["lock_version"]
    @inventory.reload
    assert_equal ["Books", true, %w[books paper]], [@inventory.title, @inventory.is_public, @inventory.tags.map(&:name).sort]
    assert_equal 1, Inventory.search("paper").count

    autosave({ fields: [{ kind: "string", slot: 2, name: "Title", description: "Book title", show: true, max_length: "50", pattern: "" },
                        { kind: "number", slot: 1, name: "Year", show: false, min: "1900", max: "" },
                        { kind: "string", slot: 9, name: "Bad slot" }] })
    assert_response :success
    fields = @inventory.reload.custom_fields
    assert_equal [%w[custom_string2 Title], %w[custom_number1 Year]], fields.map { |f| [f.column, f.name] }
    assert_equal [50, 1900], [fields[0].max_length, fields[1].min.to_i]
    assert_equal ["custom_string2"], @inventory.table_fields.map(&:column)

    autosave({ id_elements: [{ kind: "fixed", format: "B-" }, { kind: "sequence", format: "D4" }, { kind: "bogus", format: "" }] })
    assert_response :success
    assert_equal "B-0013", json["example"]
    assert_equal 2, @inventory.id_elements.count

    autosave({ fields: [] })
    assert_empty @inventory.reload.custom_fields

    autosave({ inventory: { title: "" } })
    assert_response :unprocessable_entity
    assert json["error"].present?

    post custom_id_preview_inventory_path(@inventory), params: { id_elements: [{ kind: "fixed", format: "Z" }, { kind: "sequence", format: "D2" }] }, as: :json
    assert_equal "Z13", json["example"]
  end

  test "auto-save with an outdated version is rejected and nothing is overwritten" do
    sign_in @admin # admins act as owners
    version = @inventory.lock_version
    autosave({ inventory: { title: "First" } }, version: version)
    assert_response :success
    autosave({ inventory: { title: "Second" }, id_elements: [{ kind: "guid", format: "" }] }, version: version)
    assert_response :conflict
    assert_equal "First", @inventory.reload.title
    assert_equal 0, @inventory.id_elements.count
  end

  test "only the owner and admins manage the inventory" do
    [@writer, @stranger].each do |user|
      sign_in user
      autosave({ inventory: { title: "Hacked" } })
      assert_response :forbidden
      get export_inventory_path(@inventory, format: :csv)
      assert_response :forbidden
      post inventory_accesses_path(@inventory), params: { user_id: user.id }
      delete bulk_destroy_inventories_path, params: { ids: ["#{@inventory.id}:#{@inventory.lock_version}"] }
      get inventory_path(@inventory, tab: "fields")
      assert_select "[data-fields-editor]", 0
    end
    assert_equal "Laptops", @inventory.reload.title
    assert_equal 1, @inventory.inventory_accesses.count
  end

  test "access list, autocomplete and public inventories" do
    sign_in @owner
    get autocomplete_users_path(q: "stran"), as: :json
    assert_equal [@stranger.id], json.map { |u| u["id"] }
    get autocomplete_users_path(q: @stranger.email[0, 8].upcase), as: :json
    assert_equal [@stranger.id], json.map { |u| u["id"] }

    post inventory_accesses_path(@inventory), params: { user_id: @stranger.id }
    post inventory_accesses_path(@inventory), params: { user_id: @stranger.id }
    assert_equal 2, @inventory.inventory_accesses.count
    get inventory_path(@inventory, tab: "access", q: { s: "email desc" })
    assert_select "#access-form tbody tr", 2
    emails = css_select("#access-form tbody td:nth-child(3)").map { |td| td.text.strip }
    assert_equal emails.sort.reverse, emails, "the access list is sorted by e-mail"

    delete bulk_destroy_inventory_accesses_path(@inventory), params: { ids: [@stranger.id, @writer.id] }
    assert_equal 0, @inventory.inventory_accesses.count

    sign_in @stranger
    post inventory_items_path(@inventory), params: { item: { custom_string1: "X" } }
    assert_response :redirect
    assert_equal 1, @inventory.items.count
    @inventory.update!(is_public: true)
    post inventory_items_path(@inventory), params: { item: { custom_string1: "X" } }
    assert_equal 2, @inventory.items.count
  end

  test "export" do
    sign_in @owner
    get export_inventory_path(@inventory, format: :csv)
    assert_response :success
    rows = CSV.parse(response.body)
    assert_equal %w[ID Model Price Notes Photo], rows[0].first(5)
    assert_equal [@item.custom_id, "Thinkpad", "900"], rows[1].first(3)

    if defined?(Axlsx)
      get export_inventory_path(@inventory, format: :xlsx)
      assert_response :success
    end
  end

  test "owner deletes inventories from the personal page" do
    sign_in @owner
    create_inventory(@owner, title: "Books")
    get user_path(@owner, q: { s: "title desc" })
    assert_equal %w[Laptops Books], css_select("#owned-form tbody td:nth-child(2)").map { |td| td.text.strip }
    get user_path(@owner, q: { title_cont: "lap", s: "title asc" })
    assert_select "#owned-form input[data-bulk-item]", 1
    get user_path(@owner, q: "typed by hand")
    assert_response :success

    delete bulk_destroy_inventories_path, params: { ids: ["#{@inventory.id}:#{@inventory.lock_version + 5}"] }
    assert Inventory.exists?(@inventory.id), "an outdated version must not delete"
    delete bulk_destroy_inventories_path, params: { ids: ["#{@inventory.id}:#{@inventory.lock_version}"] }
    assert_not Inventory.exists?(@inventory.id)
    assert_equal 0, Item.count
  end

  # --- items ------------------------------------------------------------------

  test "writers add, edit and delete items" do
    sign_in @writer
    get user_path(@writer, wq: { s: "items_count desc", title_cont: "lap" })
    assert_select "a[href=?]", inventory_path(@inventory)
    get user_path(@writer, wq: { title_cont: "nothing like this" })
    assert_select "a[href=?]", inventory_path(@inventory), 0
    # public inventories of other people are listed too, the user's own are not
    public_one = create_inventory(@stranger, title: "Public books", is_public: true)
    own_public = create_inventory(@writer, title: "My public list", is_public: true)
    get user_path(@writer)
    assert_select "#writable-table a[href=?]", inventory_path(public_one)
    assert_select "#writable-table a[href=?]", inventory_path(@inventory)
    assert_select "#writable-table a[href=?]", inventory_path(own_public), 0
    get inventory_path(@inventory)
    assert_select "#items-form input[data-bulk-item]", 1
    assert_select "#items-form tbody button", 0
    get new_inventory_item_path(@inventory)
    assert_response :success

    post inventory_items_path(@inventory), params: { item: { custom_string1: "Asus", custom_number2: "12.5", custom_bool1: "1", custom_select1: "B", custom_string3: "ignored" } }
    assert_redirected_to inventory_path(@inventory)
    item = @inventory.items.order(:id).last
    assert_equal ["2", "Asus", true, "B", nil, @writer.id], [item.custom_id, item.custom_string1, item.custom_bool1, item.custom_select1, item.custom_string3, item.user_id]

    post inventory_items_path(@inventory), params: { item: { custom_id: item.custom_id } }
    assert_response :unprocessable_entity
    post inventory_items_path(@inventory), params: { item: { custom_number2: "abc" } }
    assert_response :unprocessable_entity
    assert_select "input[name='item[custom_number2]'][value=abc]"

    get inventory_item_path(@inventory, item)
    assert_select "form.item-form input[name='item[lock_version]'][value='0']"
    patch inventory_item_path(@inventory, item), params: { item: { custom_string1: "Acer", lock_version: 0 } }
    assert_redirected_to inventory_item_path(@inventory, item)
    patch inventory_item_path(@inventory, item), params: { item: { custom_string1: "Late", lock_version: 0 } }
    assert_response :conflict
    assert_equal "Acer", item.reload.custom_string1

    delete bulk_destroy_inventory_items_path(@inventory), params: { ids: ["#{item.id}:0", "#{@item.id}:#{@item.lock_version}"] }
    assert_equal [item.id], @inventory.items.pluck(:id), "the changed item stays, the untouched one is deleted"
    assert_equal 1, @inventory.reload.items_count
  end

  test "items table is sorted and filtered" do
    @inventory.items.create!(custom_string1: "Asus", custom_number2: 300, user: @owner)
    @inventory.items.create!(custom_string1: "Dell", custom_number2: 1500, user: @owner)
    models = -> { css_select("#items-form tbody td:nth-child(2)").map { |td| td.text.strip } }

    get inventory_path(@inventory, q: { s: "custom_string1 asc" })
    assert_equal %w[Asus Dell Thinkpad], models.call
    get inventory_path(@inventory, q: { s: "custom_number2 desc" })
    assert_equal %w[Dell Thinkpad Asus], models.call
    get inventory_path(@inventory, q: { search_text_cont: "think" })
    assert_equal %w[Thinkpad], models.call
    get inventory_path(@inventory, q: { search_text_cont: "nothing like this" })
    assert_empty models.call
    assert_translated
  end

  test "users without write access only view items" do
    sign_in @stranger
    get inventory_path(@inventory)
    assert_select "input[data-bulk-item]", 0
    get inventory_item_path(@inventory, @item)
    assert_select "form.item-form", 0
    assert_select "img.preview-image"

    get new_inventory_item_path(@inventory)
    assert_response :redirect
    patch inventory_item_path(@inventory, @item), params: { item: { custom_string1: "No" } }
    delete bulk_destroy_inventory_items_path(@inventory), params: { ids: ["#{@item.id}:#{@item.lock_version}"] }
    assert_equal "Thinkpad", @item.reload.custom_string1
  end

  test "one like per user" do
    sign_in @stranger
    2.times { post inventory_item_like_path(@inventory, @item) }
    assert_equal 1, @item.reload.likes_count
    get inventory_item_path(@inventory, @item)
    assert_select "form[action=?] input[name=_method][value=delete]", inventory_item_like_path(@inventory, @item)
    delete inventory_item_like_path(@inventory, @item)
    assert_equal 0, @item.reload.likes_count
  end

  test "discussion" do
    sign_in @stranger
    post inventory_posts_path(@inventory), params: { body: "Hello **all**" }, as: :json
    assert_response :created
    post inventory_posts_path(@inventory), params: { body: " " }, as: :json
    assert_response :unprocessable_entity
    first = Post.last

    get inventory_posts_path(@inventory, after: 0)
    assert_select "[data-post-id='#{first.id}'] strong", "all"
    assert_select "a[href=?]", user_path(@stranger)
    get inventory_posts_path(@inventory, after: first.id)
    assert_equal "", response.body.strip
  end

  # --- admin ------------------------------------------------------------------

  test "admin manages users and may remove own admin access" do
    sign_in @stranger
    get admin_users_path
    assert_redirected_to root_path

    sign_in @admin
    get admin_users_path(q: { name_or_email_start: "own", s: "email desc" })
    assert_select "#users-form input[data-bulk-item]", 1
    assert_translated
    get admin_users_path(q: { s: "created_at desc" })
    assert_select "#users-form input[data-bulk-item]", 4

    patch bulk_admin_users_path, params: { op: "block", ids: [@writer.id] }
    patch bulk_admin_users_path, params: { op: "promote", ids: [@stranger.id] }
    assert @writer.reload.blocked?
    assert @stranger.reload.admin?

    @inventory.items.first.likes.create!(user: @owner)
    patch bulk_admin_users_path, params: { op: "delete", ids: [@owner.id] }
    assert_not User.exists?(@owner.id)
    assert_not Inventory.exists?(@inventory.id)

    patch bulk_admin_users_path, params: { op: "demote", ids: [@admin.id] }
    assert_not @admin.reload.admin?
    get admin_users_path
    assert_redirected_to root_path
  end

  test "blocked users are signed out" do
    sign_in @writer
    get new_inventory_item_path(@inventory)
    assert_response :success
    @writer.update!(blocked: true)
    get new_inventory_item_path(@inventory)
    assert_redirected_to new_user_session_path
    post user_session_path, params: { user: { email: @writer.email, password: "secret123" } }
    follow_redirect! if response.redirect?
    assert_select ".alert", /blocked/i
  end

  # --- registration -------------------------------------------------------------

  test "registration with e-mail confirmation" do
    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      post user_registration_path, params: { user: { name: "New", email: "new@example.com", password: "secret123", password_confirmation: "secret123" } }
    end
    user = User.find_by!(email: "new@example.com")
    assert_not user.confirmed?
    post user_session_path, params: { user: { email: user.email, password: "secret123" } }
    get user_path(user)
    assert_select "a[href=?]", new_user_session_path

    token = ActionMailer::Base.deliveries.last.body.to_s[/confirmation_token=([^"&]+)/, 1]
    get user_confirmation_path(confirmation_token: token)
    assert user.reload.confirmed?
    post user_session_path, params: { user: { email: user.email, password: "secret123" } }
    get user_path(user)
    assert_select "form[action=?]", inventories_path
  end

  test "sign-in through an external account" do
    auth = OmniAuth::AuthHash.new(provider: "github", uid: "42", info: { email: "Octo@Example.com", nickname: "octo" })
    user = User.from_omniauth(auth)
    assert user.persisted? && user.confirmed?
    assert_equal ["octo", "octo@example.com"], [user.name, user.email]
    assert_equal user, User.from_omniauth(auth)

    google = OmniAuth::AuthHash.new(provider: "google_oauth2", uid: "7", info: { email: @owner.email, name: "Owner" })
    assert_equal @owner, User.from_omniauth(google)
  end
end
