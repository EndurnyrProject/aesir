defmodule Aesir.Commons.StatusParams do
  @moduledoc """
  Represents various status parameters for characters in the game.
  """

  @status_params [
    # Basic status parameters (0-7)
    speed: 0,
    base_exp: 1,
    job_exp: 2,
    karma: 3,
    manner: 4,
    hp: 5,
    max_hp: 6,
    sp: 7,

    # Extended status parameters (8-15)
    max_sp: 8,
    status_point: 9,
    base_level: 11,
    skill_point: 12,
    str: 13,
    agi: 14,
    vit: 15,

    # Character attributes (16-23)
    int: 16,
    dex: 17,
    luk: 18,
    class: 19,
    zeny: 20,
    sex: 21,
    next_base_exp: 22,
    next_job_exp: 23,

    # Weight and misc (24-31)
    weight: 24,
    max_weight: 25,

    # Upper stats (32-39)
    ustr: 32,
    uagi: 33,
    uvit: 34,
    uint: 35,
    udex: 36,
    uluk: 37,

    # Combat stats (40-55)
    atk1: 41,
    atk2: 42,
    matk1: 43,
    matk2: 44,
    def1: 45,
    def2: 46,
    mdef1: 47,
    mdef2: 48,
    hit: 49,
    flee1: 50,
    flee2: 51,
    critical: 52,
    aspd: 53,
    job_level: 55,

    # Special status (56-60)
    upper: 56,
    partner: 57,
    cart: 58,
    fame: 59,
    unbreakable: 60,

    # Special indices
    cart_info: 99,
    killed_gid: 118,
    base_job: 119,
    base_class: 120,
    killer_rid: 121,
    killed_rid: 122,
    sitting: 123,
    char_move: 124,
    char_rename: 125,
    char_font: 126,
    bank_vault: 127,
    roulette_bronze: 128
  ]

  for {name, value} <- @status_params do
    def unquote(name)(), do: unquote(value)
  end

  @doc """
  Returns the numeric value for a status parameter by atom key.

  ## Examples

      iex> StatusParams.get(:weight)
      24
      
      iex> StatusParams.get(:hp)
      5
  """
  def get(param) when is_atom(param) do
    Keyword.get(@status_params, param)
  end

  @doc """
  Returns a map of all status parameters.
  """
  def all, do: Map.new(@status_params)

  @doc """
  Returns essential status parameters
  """
  def essential do
    [
      :weight,
      :max_weight,
      :hp,
      :max_hp,
      :sp,
      :max_sp,
      :base_exp,
      :next_base_exp,
      :job_exp,
      :next_job_exp,
      :skill_point,
      :base_level,
      :job_level
    ]
  end

  @doc """
  Returns character attribute parameters.
  """
  def attributes do
    [:str, :agi, :vit, :int, :dex, :luk, :ustr, :uagi, :uvit, :uint, :udex, :uluk]
  end

  @doc """
  Returns combat-related status parameters.
  """
  def combat do
    [
      :atk1,
      :atk2,
      :matk1,
      :matk2,
      :def1,
      :def2,
      :mdef1,
      :mdef2,
      :hit,
      :flee1,
      :flee2,
      :critical,
      :aspd
    ]
  end

  @doc """
  Returns weight-related parameters
  """
  def weight_params do
    [:weight, :max_weight]
  end

  @doc """
  Returns experience and level parameters
  """
  def experience_params do
    [:base_exp, :next_base_exp, :job_exp, :next_job_exp, :skill_point]
  end
end
