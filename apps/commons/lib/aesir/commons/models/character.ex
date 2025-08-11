defmodule Aesir.Commons.Models.Character do
  use Ecto.Schema

  import Ecto.Changeset

  schema "characters" do
    belongs_to :account, Aesir.Commons.Models.Account

    field :char_num, :integer
    field :name, :string
    field :class, :integer
    field :base_level, :integer, default: 1
    field :job_level, :integer, default: 1
    field :base_exp, :integer, default: 0
    field :job_exp, :integer, default: 0
    field :zeny, :integer, default: 0
    field :str, :integer, default: 1
    field :agi, :integer, default: 1
    field :vit, :integer, default: 1
    field :int, :integer, default: 1
    field :dex, :integer, default: 1
    field :luk, :integer, default: 1
    field :max_hp, :integer, default: 40
    field :hp, :integer, default: 40
    field :max_sp, :integer, default: 11
    field :sp, :integer, default: 11
    field :status_point, :integer, default: 0
    field :skill_point, :integer, default: 0
    field :option, :integer, default: 0
    field :karma, :integer, default: 0
    field :manner, :integer, default: 0
    field :party_id, :integer, default: 0
    field :guild_id, :integer, default: 0
    field :pet_id, :integer, default: 0
    field :homun_id, :integer, default: 0
    field :elemental_id, :integer, default: 0
    field :hair, :integer, default: 0
    field :hair_color, :integer, default: 0
    field :clothes_color, :integer, default: 0
    field :weapon, :integer, default: 0
    field :shield, :integer, default: 0
    field :head_top, :integer, default: 0
    field :head_mid, :integer, default: 0
    field :head_bottom, :integer, default: 0
    field :robe, :integer, default: 0
    field :last_map, :string, default: "new_1-1"
    field :last_x, :integer, default: 53
    field :last_y, :integer, default: 111
    field :save_map, :string, default: "new_1-1"
    field :save_x, :integer, default: 53
    field :save_y, :integer, default: 111
    field :partner_id, :integer, default: 0
    field :online, :integer, default: 0
    field :father, :integer, default: 0
    field :mother, :integer, default: 0
    field :child, :integer, default: 0
    field :fame, :integer, default: 0
    field :rename, :integer, default: 0
    field :delete_date, :naive_datetime
    field :moves, :integer, default: 0
    field :unban_time, :naive_datetime
    field :font, :integer, default: 0
    field :uniqueitem_counter, :integer, default: 0
    field :sex, :string, default: "M"
    field :hotkey_rowshift, :integer, default: 0
    field :clan_id, :integer, default: 0
    field :last_login, :naive_datetime
    field :title_id, :integer, default: 0
    field :show_equip, :integer, default: 0

    timestamps()
  end

  @doc false
  def changeset(character, attrs) do
    character
    |> cast(attrs, [
      :account_id,
      :char_num,
      :name,
      :class,
      :base_level,
      :job_level,
      :base_exp,
      :job_exp,
      :zeny,
      :str,
      :agi,
      :vit,
      :int,
      :dex,
      :luk,
      :max_hp,
      :hp,
      :max_sp,
      :sp,
      :status_point,
      :skill_point,
      :option,
      :karma,
      :manner,
      :party_id,
      :guild_id,
      :pet_id,
      :homun_id,
      :elemental_id,
      :hair,
      :hair_color,
      :clothes_color,
      :weapon,
      :shield,
      :head_top,
      :head_mid,
      :head_bottom,
      :robe,
      :last_map,
      :last_x,
      :last_y,
      :save_map,
      :save_x,
      :save_y,
      :partner_id,
      :online,
      :father,
      :mother,
      :child,
      :fame,
      :rename,
      :delete_date,
      :moves,
      :unban_time,
      :font,
      :uniqueitem_counter,
      :sex,
      :hotkey_rowshift,
      :clan_id,
      :last_login,
      :title_id,
      :show_equip
    ])
    |> validate_required([:account_id, :char_num, :name, :class])
    |> validate_length(:name, min: 4, max: 23)
    |> validate_inclusion(:sex, ["M", "F"])
    |> validate_number(:char_num, greater_than_or_equal_to: 0, less_than: 15)
    |> validate_number(:base_level, greater_than: 0, less_than_or_equal_to: 999)
    |> validate_number(:job_level, greater_than: 0, less_than_or_equal_to: 70)
    |> unique_constraint([:account_id, :char_num])
    |> unique_constraint(:name)
  end

  @doc """
  Creates a new character with default values for character creation.
  """
  def new(attrs \\ %{}) do
    defaults = %{
      base_level: 1,
      job_level: 1,
      base_exp: 0,
      job_exp: 0,
      zeny: 500,
      class: 0,
      status_point: 48,
      skill_point: 0,
      hp: 40,
      max_hp: 40,
      sp: 11,
      max_sp: 11,
      hair: 1,
      hair_color: 1,
      clothes_color: 1,
      weapon: 0,
      shield: 0,
      head_top: 0,
      head_mid: 0,
      head_bottom: 0,
      robe: 0,
      last_map: "new_1-1",
      last_x: 53,
      last_y: 111,
      save_map: "new_1-1",
      save_x: 53,
      save_y: 111,
      option: 0,
      karma: 0,
      manner: 0,
      party_id: 0,
      guild_id: 0,
      delete_date: nil,
      unban_time: nil,
      rename: 0,
      moves: 0
    }

    %__MODULE__{}
    |> changeset(Map.merge(defaults, attrs))
  end

  @doc """
  Validates character creation data.
  """
  def validate_creation(attrs) do
    with {:ok, name} <- validate_name(attrs[:name]),
         {:ok, stats} <- validate_stats(attrs),
         {:ok, slot} <- validate_slot(attrs[:slot]) do
      {:ok, %{name: name, stats: stats, slot: slot}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Validates character name.
  """
  def validate_name(name) when is_binary(name) do
    cond do
      String.length(name) < 4 ->
        {:error, :name_too_short}

      String.length(name) > 23 ->
        {:error, :name_too_long}

      not String.match?(name, ~r/^[a-zA-Z0-9_]+$/) ->
        {:error, :name_invalid_chars}

      String.contains?(String.downcase(name), ["gm", "admin", "test"]) ->
        {:error, :name_forbidden}

      true ->
        {:ok, name}
    end
  end

  def validate_name(_), do: {:error, :name_required}

  @doc """
  Validates character stats for creation.
  Modern clients MUST send all stats as 1 - anything else is packet tampering.
  """
  def validate_stats(attrs) do
    required_stats = [:str, :agi, :vit, :int, :dex, :luk]

    stats =
      required_stats
      |> Enum.map(&{&1, (attrs[:stats] && attrs[:stats][&1]) || 1})
      |> Enum.into(%{})

    # Modern clients (PACKETVER >= 20151001) ALWAYS send all stats as 1
    # If any stat is not 1, it's packet tampering
    if Enum.all?(Map.values(stats), &(&1 == 1)) do
      {:ok, stats}
    else
      {:error, :stats_invalid_total}
    end
  end

  @doc """
  Validates character slot number.
  """
  def validate_slot(slot) when is_integer(slot) and slot >= 0 and slot <= 14 do
    {:ok, slot}
  end

  def validate_slot(_), do: {:error, :invalid_slot}

  @doc """
  Checks if character is marked for deletion.
  """
  def marked_for_deletion?(%__MODULE__{delete_date: nil}), do: false
  def marked_for_deletion?(%__MODULE__{delete_date: _}), do: true

  @doc """
  Checks if character is banned.
  """
  def banned?(%__MODULE__{unban_time: nil}), do: false

  def banned?(%__MODULE__{unban_time: unban_time}) do
    NaiveDateTime.compare(unban_time, NaiveDateTime.utc_now()) == :gt
  end
end
