defmodule Aesir.CharServer.Character do
  @moduledoc """
  Character data structure for Ragnarok Online characters.

  Based on the rathena mmo_charstatus structure, this represents
  all character data needed for the char server.
  """

  @type job_class :: 0..999
  @type stat_value :: 0..255
  @type point_value :: 0..65535
  @type coordinate :: {map_name :: String.t(), x :: integer(), y :: integer()}

  # Core identifiers
  defstruct [
    # Unique character ID
    :char_id,

    # Owner account ID
    :account_id,

    # Character slot (0-8)

    :char_num,

    # Basic info

    # Character name
    :name,

    # Job class ID
    :class,

    # Base level
    :base_level,

    # Job level
    :job_level,

    # Base experience
    :base_exp,

    # Job experience
    :job_exp,

    # Money

    :zeny,

    # Stats

    # Strength
    :str,

    # Agility
    :agi,

    # Vitality
    :vit,

    # Intelligence
    :int,

    # Dexterity
    :dex,

    # Luck

    :luk,

    # Points

    # Available status points
    :status_point,

    # Available skill points

    :skill_point,

    # HP/SP

    # Current HP
    :hp,

    # Maximum HP
    :max_hp,

    # Current SP
    :sp,

    # Maximum SP

    :max_sp,

    # Appearance

    # Hair style
    :hair,

    # Hair color
    :hair_color,

    # Clothes color
    :clothes_color,

    # Body sprite (for expanded classes)

    :body,

    # Equipment view IDs (for character select display)

    # Weapon view ID
    :weapon,

    # Shield view ID
    :shield,

    # Top headgear view ID
    :head_top,

    # Mid headgear view ID
    :head_mid,

    # Bottom headgear view ID
    :head_bottom,

    # Robe view ID

    :robe,

    # Position data

    # Last position {map, x, y}
    :last_point,

    # Save position {map, x, y}

    :save_point,

    # Status

    # Status options (riding, etc.)
    :option,

    # Karma value
    :karma,

    # Manner value

    :manner,

    # Guild/Party

    # Party ID (0 if none)
    :party_id,

    # Guild ID (0 if none)

    :guild_id,

    # Timestamps

    # Deletion date (0 if not marked for deletion)
    :delete_date,

    # Unban time (0 if not banned)
    :unban_time,

    # Rename flag
    :rename_flag,

    # Number of character moves

    :moves,

    # Creation time

    # Character creation timestamp
    :created_at,

    # Last update timestamp
    :updated_at
  ]

  @type t :: %__MODULE__{
          char_id: non_neg_integer() | nil,
          account_id: non_neg_integer(),
          char_num: 0..8,
          name: String.t(),
          class: job_class(),
          base_level: 1..255,
          job_level: 1..255,
          base_exp: non_neg_integer(),
          job_exp: non_neg_integer(),
          zeny: non_neg_integer(),
          str: stat_value(),
          agi: stat_value(),
          vit: stat_value(),
          int: stat_value(),
          dex: stat_value(),
          luk: stat_value(),
          status_point: point_value(),
          skill_point: point_value(),
          hp: non_neg_integer(),
          max_hp: non_neg_integer(),
          sp: non_neg_integer(),
          max_sp: non_neg_integer(),
          hair: non_neg_integer(),
          hair_color: non_neg_integer(),
          clothes_color: non_neg_integer(),
          body: non_neg_integer(),
          weapon: non_neg_integer(),
          shield: non_neg_integer(),
          head_top: non_neg_integer(),
          head_mid: non_neg_integer(),
          head_bottom: non_neg_integer(),
          robe: non_neg_integer(),
          last_point: coordinate(),
          save_point: coordinate(),
          option: non_neg_integer(),
          karma: integer(),
          manner: integer(),
          party_id: non_neg_integer(),
          guild_id: non_neg_integer(),
          delete_date: non_neg_integer(),
          unban_time: non_neg_integer(),
          rename_flag: non_neg_integer(),
          moves: non_neg_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @doc """
  Creates a new character with default values for character creation.
  """
  def new(attrs \\ %{}) do
    now = DateTime.utc_now()

    defaults = %{
      char_id: nil,
      base_level: 1,
      job_level: 1,
      base_exp: 0,
      # Starting zeny
      job_exp: 0,
      # Novice
      zeny: 500,
      # Starting status points
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
      body: 0,
      weapon: 0,
      shield: 0,
      head_top: 0,
      head_mid: 0,
      head_bottom: 0,
      # Default spawn point
      robe: 0,
      last_point: {"new_1-1", 53, 111},
      save_point: {"new_1-1", 53, 111},
      option: 0,
      karma: 0,
      manner: 0,
      party_id: 0,
      guild_id: 0,
      delete_date: 0,
      unban_time: 0,
      rename_flag: 0,
      moves: 0,
      created_at: now,
      updated_at: now
    }

    struct(__MODULE__, Map.merge(defaults, attrs))
  end

  @doc """
  Validates character creation data.
  """
  def validate_creation(attrs) do
    with {:ok, name} <- validate_name(attrs[:name]),
         {:ok, stats} <- validate_stats(attrs),
         {:ok, slot} <- validate_slot(attrs[:char_num]) do
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
  """
  def validate_stats(attrs) do
    required_stats = [:str, :agi, :vit, :int, :dex, :luk]

    stats =
      required_stats
      |> Enum.map(&{&1, attrs[&1] || 1})
      |> Enum.into(%{})

    total_stats = Enum.sum(Map.values(stats))

    cond do
      Enum.any?(Map.values(stats), &(&1 < 1 or &1 > 9)) ->
        {:error, :stats_out_of_range}

      # 6 stats * 1 base + 24 points = 30
      total_stats != 30 ->
        {:error, :stats_invalid_total}

      true ->
        {:ok, stats}
    end
  end

  @doc """
  Validates character slot number.
  """
  def validate_slot(slot) when is_integer(slot) and slot >= 0 and slot <= 8 do
    {:ok, slot}
  end

  def validate_slot(_), do: {:error, :invalid_slot}

  @doc """
  Generates a unique character ID.
  """
  def generate_char_id do
    System.unique_integer([:positive, :monotonic])
  end

  @doc """
  Updates character's timestamp.
  """
  def touch(%__MODULE__{} = character) do
    %{character | updated_at: DateTime.utc_now()}
  end

  @doc """
  Checks if character is marked for deletion.
  """
  def marked_for_deletion?(%__MODULE__{delete_date: delete_date}) do
    delete_date > 0
  end

  @doc """
  Checks if character is banned.
  """
  def banned?(%__MODULE__{unban_time: unban_time}) do
    unban_time > 0 and unban_time > System.system_time(:second)
  end
end
