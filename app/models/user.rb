class User < ApplicationRecord
  THEMES = %w[light dark].freeze

  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable, :confirmable,
         :omniauthable, omniauth_providers: %i[google_oauth2 github]

  has_many :inventories
  has_many :inventory_accesses
  has_many :accessible_inventories, through: :inventory_accesses, source: :inventory

  validates :name, presence: true, length: { maximum: 100 }
  validates :locale, inclusion: { in: ->(_) { I18n.available_locales.map(&:to_s) } }, allow_nil: true
  validates :theme, inclusion: { in: THEMES }, allow_nil: true

  # Prefix search by name or e-mail, served by the lower(...) indexes.
  scope :starting_with, lambda { |prefix|
    pattern = "#{sanitize_sql_like(prefix.to_s.downcase)}%"
    where("lower(name) LIKE :p OR lower(email) LIKE :p", p: pattern)
  }

  # Columns that user tables may be sorted and filtered by (Ransack).
  # Password and token columns are deliberately left out.
  def self.ransackable_attributes(_auth_object = nil)
    %w[name email admin blocked created_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  def self.from_omniauth(auth)
    user = find_by(provider: auth.provider, uid: auth.uid.to_s)
    return user if user

    email = auth.info.email.to_s.downcase
    return nil if email.blank?

    user = find_by(email: email)
    if user
      user.update(provider: auth.provider, uid: auth.uid.to_s)
      user.confirm unless user.confirmed?
      return user
    end

    user = new(
      provider: auth.provider, uid: auth.uid.to_s, email: email,
      name: (auth.info.name.presence || auth.info.nickname.presence || email.split("@").first).first(100),
      password: Devise.friendly_token(32)
    )
    user.skip_confirmation!
    user.save
    user
  end

  # Blocked users cannot sign in and are signed out on their next request.
  def active_for_authentication?
    super && !blocked?
  end

  def inactive_message
    blocked? ? :blocked : super
  end
end
