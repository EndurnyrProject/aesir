defmodule Aesir.Commons.Models.Account do
  use Ecto.Schema

  import Ecto.Changeset

  schema "accounts" do
    field :userid, :string
    field :user_pass, :string
    field :sex, :string, default: "M"
    field :email, :string
    field :group_id, :integer, default: 0
    field :state, :integer, default: 0
    field :unban_time, :naive_datetime
    field :expiration_time, :naive_datetime
    field :logincount, :integer, default: 0
    field :lastlogin, :naive_datetime
    field :last_ip, :string
    field :birthdate, :date
    field :character_slots, :integer, default: 9
    field :pincode, :string
    field :pincode_change, :naive_datetime
    field :vip_time, :naive_datetime
    field :old_group, :integer, default: 0
    field :web_auth_token, :string
    field :web_auth_token_enabled, :integer, default: 0

    has_many :characters, Aesir.Commons.Models.Character

    timestamps()
  end

  @doc false
  def changeset(account, attrs) do
    account
    |> cast(attrs, [
      :userid,
      :user_pass,
      :sex,
      :email,
      :group_id,
      :state,
      :unban_time,
      :expiration_time,
      :logincount,
      :lastlogin,
      :last_ip,
      :birthdate,
      :character_slots,
      :pincode,
      :pincode_change,
      :vip_time,
      :old_group,
      :web_auth_token,
      :web_auth_token_enabled
    ])
    |> validate_required([:userid, :user_pass, :email])
    |> validate_format(:email, ~r/@/)
    |> validate_inclusion(:sex, ["M", "F"])
    |> validate_length(:userid, min: 4, max: 23)
    |> validate_length(:user_pass, min: 4, max: 255)
    |> validate_length(:pincode, is: 4)
    |> unique_constraint(:userid)
    |> unique_constraint(:email)
  end

  @doc """
  Changeset for login validation without email requirement
  """
  def login_changeset(account, attrs) do
    account
    |> cast(attrs, [:userid, :user_pass])
    |> validate_required([:userid, :user_pass])
    |> validate_length(:userid, min: 4, max: 23)
    |> validate_length(:user_pass, min: 4, max: 255)
  end
end
