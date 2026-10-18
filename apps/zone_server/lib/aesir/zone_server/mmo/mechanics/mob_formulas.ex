defmodule Aesir.ZoneServer.Mmo.Mechanics.MobFormulas do
  @moduledoc """
  Pure monster base construction and mode-specific formula contracts.

  Construction uses captured spawn inputs and retains an unmodified base;
  held status contributions belong to subsequent selective calculations.

  Shared helpers implement the status MATK steps both modes take on a monster:
  flat (pseudo-buff) MATK and Mystical Amplification's percentage, each added
  to both bounds and truncated. A MATK rate and the `:atk` channel are player
  bonuses (item scripts, or renewal equipment ATK a monster's damage never
  sums) and never apply.
  """

  import Bitwise, only: [bor: 2]

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobMode
  alias Aesir.ZoneServer.Mmo.StatusEffect.CalcFlags
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.Mob.Calculated
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @typedoc "Mob definition used by formula implementations."
  @type mob_data :: MobDefinition.t()

  @typedoc "A unit's aggregated status modifiers."
  @type modifiers :: %{optional(atom()) => number()}

  @typedoc "A roll's minimum and maximum."
  @type bounds :: {integer(), integer()}

  @emperium_id 1_288

  @doc "Builds an unmodified first-calculation snapshot without held statuses."
  @callback base(MobState.t()) :: Calculated.t()

  @doc "Builds raw base data with captured spawn adjustments, never held statuses."
  @callback base(MobState.t(), keyword()) :: Calculated.t()

  @doc "Expands monster-only primary dependencies without player resource or timing edges."
  @callback expand_calc_flags([CalcFlags.flag()]) :: [CalcFlags.flag()]

  @doc "Recalculates selected combat fields from the raw base and captured held entries."
  @callback recalculate_combat(MobState.t(), [StatusEntry.t()], [CalcFlags.flag()]) ::
              Calculated.t()

  @doc false
  @spec expand_calc_flags([CalcFlags.flag()], :renewal | :pre_renewal) :: [CalcFlags.flag()]
  def expand_calc_flags(flags, mode) do
    dependencies = %{
      "Str" => ~w(Batk),
      "Agi" => if(mode == :renewal, do: ~w(Flee Def2), else: ~w(Flee)),
      "Vit" => ~w(Def2 Mdef2),
      "Int" => ~w(Matk Mdef2),
      "Dex" => if(mode == :renewal, do: ~w(Batk Hit Matk Mdef2), else: ~w(Batk Hit)),
      "Luk" =>
        if(mode == :renewal, do: ~w(Batk Cri Flee2 Matk Hit Flee), else: ~w(Batk Cri Flee2))
    }

    selected = CalcFlags.normalize_flags!(Map.new(flags, &{&1, true}))
    selected = if "All" in selected, do: CalcFlags.all(), else: selected

    selected
    |> Enum.flat_map(&[&1 | Map.get(dependencies, &1, [])])
    |> Enum.uniq()
    |> Enum.sort()
  end

  @callback calculate_hit(mob_data()) :: integer()
  @callback calculate_flee(mob_data()) :: integer()
  @callback calculate_perfect_dodge(mob_data()) :: integer()
  @callback calculate_aspd(mob_data()) :: integer()
  @callback calculate_base_attack(mob_data()) :: integer()

  @doc "The weapon roll's bounds from the database attack and status (weapon) ATK."
  @callback attack_bounds(mob_data(), modifiers()) :: bounds()

  @doc """
  Status ATK added after the roll, from the current STR and the base status ATK
  a guardian's Guard Up grants (`status_calc_mob`).
  """
  @callback status_attack(mob_data(), str :: integer(), guard_up :: integer(), modifiers()) ::
              integer()

  @doc "MATK bounds from the current INT and the status MATK stages."
  @callback magic_attack_bounds(mob_data(), int :: integer(), modifiers()) :: bounds()
  @callback calculate_defense(mob_data()) :: integer()
  @callback calculate_soft_defense(mob_data()) :: integer()
  @callback calculate_magic_defense(mob_data()) :: integer()
  @callback calculate_soft_mdef(mob_data()) :: integer()

  @doc false
  @spec adjusted_base(MobState.t(), keyword(), module(), 8 | 16) :: Calculated.t()
  def adjusted_base(state, opts, formulas, def_bits) do
    base = formulas.base(state)
    bonus = Keyword.get(opts, :stat_bonus, %{})
    hp = Keyword.get(opts, :hp_override)
    master_speed = Keyword.get(opts, :master_speed)
    form_modes = Keyword.get(opts, :form_modes, state.mob_data.modes || [])
    base = %{base | mode: MobMode.mask(form_modes)}

    base = inherit_base_speed(base, master_speed)

    level_up? =
      Keyword.get(opts, :level_up, false) and runtime_level(state) > state.mob_data.level

    special_size = Keyword.get(opts, :special_size)

    custom? =
      Enum.any?([
        state.mob_id == @emperium_id,
        map_size(bonus) > 0,
        is_integer(hp),
        is_integer(master_speed),
        level_up?,
        special_size in [:medium, :large],
        is_integer(state.master_id) and state.master_id > 0,
        is_integer(state.owner_player_id) and state.owner_player_id > 0
      ])

    base =
      if level_up?,
        do: apply_base_level(base, runtime_level(state) - state.mob_data.level),
        else: base

    base =
      if Keyword.get(opts, :size_influence, false),
        do: apply_base_size(base, special_size),
        else: base

    base = if custom?, do: recalculate_misc(state, base, formulas), else: base
    attack = Map.get(bonus, :atk, 0)

    adjusted = %{
      base
      | batk: signed(base.batk + attack, 32),
        watk_min: Integer.mod(base.watk_min + attack, 65_536),
        watk_max: Integer.mod(base.watk_max + attack, 65_536),
        def: signed(base.def + Map.get(bonus, :def, 0), def_bits),
        mdef: signed(base.mdef + Map.get(bonus, :mdef, 0), def_bits),
        aspd_rate: signed(base.aspd_rate - Map.get(bonus, :aspd_rate, 0), 16),
        max_hp: adjusted_hp(base.max_hp, hp, Keyword.get(opts, :guardian_hp_bonus))
    }

    apply_summon(adjusted, opts)
  end

  defp adjusted_hp(base_hp, _override, bonus) when is_integer(bonus),
    do: Integer.mod(base_hp + bonus, 4_294_967_296)

  defp adjusted_hp(_base_hp, override, _bonus) when is_integer(override),
    do: Integer.mod(override, 4_294_967_296)

  defp adjusted_hp(base_hp, _override, _bonus), do: base_hp

  defp apply_summon(base, opts) do
    case Keyword.get(opts, :summon_kind) do
      :flora ->
        %{base | mode: bor(base.mode, 0x84)}

      :sphere ->
        hp = 2_000 + 400 * Keyword.fetch!(opts, :summon_level)
        %{base | max_hp: Integer.mod(hp, 4_294_967_296)}

      _ ->
        base
    end
  end

  defp inherit_base_speed(base, speed) when is_integer(speed),
    do: %{base | speed: max(Integer.mod(speed, 65_536), 20)}

  defp inherit_base_speed(base, _speed), do: base

  defp runtime_level(state) do
    level = MobState.get_level(state)
    if level in 1..275, do: level, else: state.mob_data.level
  end

  defp apply_base_level(base, difference) do
    base = update_primaries(base, &signed(&1 + difference, 16))

    %{
      base
      | max_hp: Integer.mod(base.max_hp + difference * base.vit, 4_294_967_296),
        max_sp: Integer.mod(base.max_sp + difference * base.int, 4_294_967_296),
        speed: base.speed - min(max(difference, 0), base.speed - 10)
    }
  end

  defp apply_base_size(base, :medium) do
    base =
      update_primaries(base, fn value ->
        case div(value, 2) do
          0 -> 1
          halved -> halved
        end
      end)

    %{base | max_hp: max(div(base.max_hp, 2), 1), max_sp: max(div(base.max_sp, 2), 1)}
  end

  defp apply_base_size(base, :large) do
    base = update_primaries(base, &signed(&1 * 2, 16))

    %{
      base
      | max_hp: Integer.mod(base.max_hp * 2, 4_294_967_296),
        max_sp: Integer.mod(base.max_sp * 2, 4_294_967_296)
    }
  end

  defp apply_base_size(base, _size), do: base

  defp update_primaries(base, calculate) do
    Enum.reduce([:str, :agi, :vit, :int, :dex, :luk], base, fn field, base ->
      Map.update!(base, field, calculate)
    end)
  end

  defp recalculate_misc(state, base, formulas) do
    data = %{
      state.mob_data
      | level: runtime_level(state),
        stats: Map.take(base, [:str, :agi, :vit, :int, :dex, :luk]),
        atk: base.watk_min,
        atk2: base.watk_max
    }

    misc = formulas.base(%{state | mob_data: data})

    fields = [
      :batk,
      :hit,
      :flee,
      :cri,
      :flee2,
      :def2,
      :mdef2,
      :watk_min,
      :watk_max,
      :matk_min,
      :matk_max
    ]

    struct!(base, Map.take(misc, fields))
  end

  defp signed(value, bits) do
    range = Integer.pow(2, bits)
    half = div(range, 2)
    Integer.mod(value + half, range) - half
  end

  @doc false
  @spec base_snapshot(MobState.t(), map()) :: Calculated.t()
  def base_snapshot(state, mode_values) do
    data = state.mob_data
    {element, element_level} = data.element
    primaries = Map.take(data.stats, [:str, :agi, :vit, :int, :dex, :luk])

    values =
      Map.merge(primaries, %{
        watk: 0,
        watk2: 0,
        cri: 0,
        flee2: 0,
        def_ele: element,
        ele_lv: element_level,
        attack_element: :neutral,
        speed: data.walk_speed,
        amotion: data.attack_motion,
        client_amotion: data.client_attack_motion,
        adelay: max(data.attack_delay, data.attack_motion),
        dmotion: data.damage_motion,
        aspd_rate: 1_000,
        max_hp: max(data.hp, 1),
        max_sp: max(data.sp, 1),
        mode: MobMode.mask(data.modes || []),
        class: data.class,
        race: data.race,
        size: data.size
      })

    values = Map.merge(values, mode_values)

    values =
      Enum.reduce(
        [
          :watk_min,
          :watk_max,
          :watk,
          :watk2,
          :matk_min,
          :matk_max,
          :speed,
          :amotion,
          :client_amotion,
          :adelay,
          :dmotion
        ],
        values,
        fn field, values ->
          Map.update!(values, field, &Integer.mod(&1, 65_536))
        end
      )

    values =
      Enum.reduce([:str, :agi, :vit, :int, :dex, :luk], values, fn field, values ->
        Map.update!(values, field, &(Integer.mod(&1 + 32_768, 65_536) - 32_768))
      end)

    struct!(Calculated, values)
  end

  @doc "Adds flat status MATK to both bounds."
  @spec add_flat(bounds(), modifiers()) :: bounds()
  def add_flat({min, max}, modifiers) do
    flat = Map.get(modifiers, :matk, 0)
    {min + flat, max + flat}
  end

  @doc "Applies Mystical Amplification's percentage to both bounds."
  @spec amplify(bounds(), modifiers()) :: bounds()
  def amplify({min, max}, modifiers) do
    rate = Map.get(modifiers, :base_matk_rate, 0)
    {min + div(min * rate, 100), max + div(max * rate, 100)}
  end

  @doc "Floors both bounds at zero."
  @spec floor_zero(bounds()) :: bounds()
  def floor_zero({min, max}), do: {max(min, 0), max(max, 0)}
end
