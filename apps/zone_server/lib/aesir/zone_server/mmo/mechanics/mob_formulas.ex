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

  import Bitwise, only: [band: 2, bnot: 1, bor: 2]

  alias Aesir.ZoneServer.Mmo.Element
  alias Aesir.ZoneServer.Mmo.Mechanics.MobFormulas.Combat
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

  @first_generation_mode_bits 0x000F_FFF
  @min_walk_speed 20
  @max_walk_speed 1_000
  @min_speed_rate 40
  @min_amotion 100
  @max_delay 8_000
  @max_aspd_rate 32_767
  @max_resource 4_294_967_295
  @max_mode 2_147_483_647
  @break_ankle 0x01
  @break_wrist 0x02
  @break_knee 0x04
  @nibelungen_hp_rate 4
  @aspd_potions [:sc_aspdpotion3, :sc_aspdpotion2, :sc_aspdpotion1, :sc_aspdpotion0]

  @doc "Builds an unmodified first-calculation snapshot without held statuses."
  @callback base(MobState.t()) :: Calculated.t()

  @doc "Recalculates the selected fields from the raw base and the captured held entries."
  @callback recalculate(MobState.t(), [StatusEntry.t()], [CalcFlags.flag()]) :: Calculated.t()

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

  @doc false
  @spec recalculate(MobState.t(), [StatusEntry.t()], [CalcFlags.flag()], :renewal | :pre_renewal) ::
          Calculated.t()
  def recalculate(state, entries, flags, mode) do
    base = state.base
    held = Map.new(entries, &{&1.type, &1})

    state
    |> Combat.recalculate(entries, flags, mode)
    |> recalculate_speed(base, held, flags, mode)
    |> recalculate_aspd(base, held, flags, mode)
    |> recalculate_resources(base, held, flags, mode)
    |> recalculate_elements(base, held, flags)
    |> recalculate_mode(held, flags)
  end

  # Movement: one strongest slow and one strongest haste, floored at 40 percent,
  # then the resource-free overrides (Steel Body, Defender) and the final clamp.
  defp recalculate_speed(calculated, base, held, flags, mode) do
    if "Speed" in flags,
      do: %{calculated | speed: walk_speed(base.speed, held, mode)},
      else: calculated
  end

  defp walk_speed(base_speed, held, mode) do
    rate = 100 + speed_slow(held, mode)
    rate = max(rate - speed_haste(held, mode), @min_speed_rate)

    speed = if rate == 100, do: base_speed, else: div(base_speed * rate, 100)
    speed = if Map.has_key?(held, :sc_steelbody), do: 200, else: speed
    speed = if Map.has_key?(held, :sc_defender), do: max(speed, 200), else: speed

    speed |> min(@max_walk_speed) |> max(@min_walk_speed)
  end

  defp speed_slow(held, mode) do
    [
      if(mode == :renewal, do: value(held, :sc_ensemblefatigue, :val2), else: 0),
      fixed(held, :sc_decreaseagi, 25),
      fixed(held, :sc_quagmire, 50),
      value(held, :sc_dontforgetme, :val3),
      fixed(held, :sc_curse, 300),
      joint_beat_slow(held),
      cloaking_slow(held),
      fixed(held, :sc_gospel_slow, 75),
      value(held, :sc_slowdown, :val1)
    ]
    |> Enum.max()
  end

  defp speed_haste(held, _mode) do
    [
      fixed(held, :sc_increaseagi, 25),
      2 * value(held, :sc_windwalk, :val1),
      value(held, :sc_avoid, :val2),
      value(held, :sc_emergency_move, :val2),
      cloaking_haste(held)
    ]
    |> Enum.max()
  end

  defp joint_beat_slow(held) do
    wounds = value(held, :sc_jointbeat, :val2)
    broken(wounds, @break_ankle, 50) + broken(wounds, @break_knee, 30)
  end

  defp cloaking_slow(held) do
    case held[:sc_cloaking] do
      %{val1: level} = entry -> if cloaking_wall?(entry), do: 0, else: cloaking_penalty(level)
      nil -> 0
    end
  end

  defp cloaking_penalty(level) when level < 3, do: 300
  defp cloaking_penalty(level), do: 30 - 3 * level

  defp cloaking_haste(held) do
    case held[:sc_cloaking] do
      %{val1: level} = entry -> if cloaking_wall?(entry), do: cloaking_bonus(level), else: 0
      nil -> 0
    end
  end

  defp cloaking_bonus(level) when level >= 10, do: 25
  defp cloaking_bonus(level), do: 3 * level - 3

  defp cloaking_wall?(%{state: state}), do: Map.get(state || %{}, :adjacent_impassable?, false)

  # Attack timing: the rate is a delay factor in thousandths, the strongest
  # quicken bucket is subtracted, then the potion tier and the remaining
  # penalties in order. Motion and delay clamp to 100..8000, and the delay
  # never exceeds what the rate itself would set.
  defp recalculate_aspd(calculated, base, held, flags, mode) do
    if "Aspd" in flags do
      rate = aspd_rate(base.aspd_rate, held, mode)
      amotion = clamp(div(base.amotion * rate, 1000), @min_amotion, @max_delay)
      adelay = clamp(div(base.adelay * min(rate, 1000), 1000), amotion, @max_delay)

      %{calculated | aspd_rate: rate, amotion: amotion, adelay: adelay}
    else
      calculated
    end
  end

  defp aspd_rate(rate, held, mode) do
    rate
    |> Kernel.-(quicken_rate(held, mode))
    |> Kernel.-(aspd_potion(held))
    |> aspd_penalties(held, mode)
    |> clamp(0, @max_aspd_rate)
  end

  defp aspd_penalties(rate, held, mode) do
    rate
    |> Kernel.+(ensemble_fatigue_aspd(held, mode))
    |> Kernel.+(fixed(held, :sc_steelbody, 250))
    |> Kernel.+(defender_penalty(held))
    |> Kernel.+(fixed(held, :sc_gospel_slow, 250))
    |> Kernel.+(gravitation_penalty(held, mode))
    |> Kernel.+(joint_beat_aspd(held))
  end

  defp quicken_rate(held, mode) do
    [
      value(held, :sc_twohandquicken, :val2),
      value(held, :sc_adrenaline2, :val3),
      value(held, :sc_adrenaline, :val3),
      mode_restricted_quicken(held, mode),
      value(held, :sc_fleet, :val2),
      value(held, :sc_assncross, :val2)
    ]
    |> Enum.max()
  end

  defp mode_restricted_quicken(held, :pre_renewal), do: value(held, :sc_spearquicken, :val2)
  defp mode_restricted_quicken(_held, :renewal), do: 0

  defp aspd_potion(held) do
    Enum.find_value(@aspd_potions, 0, fn type ->
      if Map.has_key?(held, type), do: value(held, type, :val2), else: nil
    end)
  end

  defp ensemble_fatigue_aspd(held, :renewal), do: value(held, :sc_ensemblefatigue, :val2)
  defp ensemble_fatigue_aspd(_held, :pre_renewal), do: 0

  defp gravitation_penalty(held, :pre_renewal), do: value(held, :sc_gravitation, :val2)
  defp gravitation_penalty(_held, :renewal), do: 0

  defp defender_penalty(held) do
    case held[:sc_defender] do
      %{state: state} -> Map.get(state || %{}, :aspd_penalty, 0)
      nil -> 0
    end
  end

  defp joint_beat_aspd(held) do
    wounds = value(held, :sc_jointbeat, :val2)
    broken(wounds, @break_wrist, 250) + broken(wounds, @break_knee, 100)
  end

  defp broken(wounds, flag, amount), do: if(band(wounds, flag) != 0, do: amount, else: 0)

  # Resources: flat bonuses first, then the aggregated rate, and calculate the
  # ceiling only. Current HP and SP belong to the owning session.
  defp recalculate_resources(calculated, base, held, flags, mode) do
    calculated =
      if "MaxHp" in flags,
        do: %{calculated | max_hp: max_hp(base.max_hp, held, mode)},
        else: calculated

    if "MaxSp" in flags,
      do: %{calculated | max_sp: max_sp(base.max_sp, held)},
      else: calculated
  end

  defp max_hp(base_hp, held, mode) do
    flat = if mode == :renewal, do: value(held, :sc_angelus, :val1) * 50, else: 0

    rate =
      100 +
        value(held, :sc_incmhprate, :val1) +
        value(held, :sc_appleidun, :val2) +
        value(held, :sc_deluge, :val2) +
        nibelungen_hp_rate(held, mode)

    resource(base_hp + flat, rate)
  end

  defp nibelungen_hp_rate(held, :renewal) do
    if value(held, :sc_nibelungen, :val2) == @nibelungen_hp_rate, do: 30, else: 0
  end

  defp nibelungen_hp_rate(_held, :pre_renewal), do: 0

  defp max_sp(base_sp, held) do
    bonus = value(held, :sc_incmsprate, :val1) + value(held, :sc_serviceforyou, :val2)
    resource(base_sp, 100 + max(bonus, -100))
  end

  defp resource(value, 100), do: clamp(value, 1, @max_resource)
  defp resource(value, rate), do: clamp(div(value * rate, 100), 1, @max_resource)

  # Elements: separate attack and defence recipes. Defences read the raw base
  # when no override is held, and the attack priority is fixed, not last applied.
  defp recalculate_elements(calculated, base, held, flags) do
    calculated =
      if "Atk_Ele" in flags,
        do: %{calculated | attack_element: attack_element(base.attack_element, held)},
        else: calculated

    if "Def_Ele" in flags, do: defense_element(calculated, base, held), else: calculated
  end

  defp attack_element(base_element, held) do
    cond do
      Map.has_key?(held, :sc_enchantarms) -> Element.from_id!(value(held, :sc_enchantarms, :val1))
      Map.has_key?(held, :sc_waterweapon) -> :water
      Map.has_key?(held, :sc_earthweapon) -> :earth
      Map.has_key?(held, :sc_fireweapon) -> :fire
      Map.has_key?(held, :sc_windweapon) -> :wind
      Map.has_key?(held, :sc_encpoison) -> :poison
      Map.has_key?(held, :sc_aspersio) -> :holy
      true -> base_element
    end
  end

  defp defense_element(calculated, base, held) do
    cond do
      Map.has_key?(held, :sc_freeze) -> %{calculated | def_ele: :water, ele_lv: 1}
      Map.has_key?(held, :sc_stone) -> %{calculated | def_ele: :earth, ele_lv: 1}
      Map.has_key?(held, :sc_benedictio) -> %{calculated | def_ele: :holy, ele_lv: 1}
      Map.has_key?(held, :sc_elementalchange) -> elemental_defense(calculated, held)
      true -> %{calculated | def_ele: base.def_ele, ele_lv: base.ele_lv}
    end
  end

  defp elemental_defense(calculated, held) do
    element = Element.from_id!(value(held, :sc_elementalchange, :val2))
    level = clamp(value(held, :sc_elementalchange, :val1), 1, 4)
    %{calculated | def_ele: element, ele_lv: level}
  end

  # Mode: an explicit set mask replaces the declared first-generation bits, then
  # the add and remove masks apply in that order, and the class follows the result.
  defp recalculate_mode(calculated, held, flags) do
    case {held[:sc_modechange], "Mode" in flags} do
      {%StatusEntry{} = entry, true} ->
        mode = mode_masks(calculated.mode, entry)
        %{calculated | mode: mode, class: MobMode.class(MobMode.from_mask(mode))}

      _absent_or_unselected ->
        calculated
    end
  end

  defp mode_masks(mode, entry) do
    mode =
      if entry.val2 != 0,
        do: bor(band(mode, bnot(@first_generation_mode_bits)), entry.val2),
        else: mode

    mode = if entry.val3 != 0, do: bor(mode, entry.val3), else: mode
    mode = if entry.val4 != 0, do: band(mode, bnot(entry.val4)), else: mode
    clamp(mode, 0, @max_mode)
  end

  defp clamp(value, minimum, maximum), do: value |> max(minimum) |> min(maximum)

  @doc false
  @spec value(map(), atom(), atom()) :: integer()
  def value(held, status, field) do
    case held[status] do
      nil -> 0
      entry -> Map.fetch!(entry, field)
    end
  end

  @doc false
  @spec fixed(map(), atom(), integer()) :: integer()
  def fixed(held, status, amount), do: if(Map.has_key?(held, status), do: amount, else: 0)

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
    # `status_calc_misc` derives the monster's roll bounds from the raw database
    # attack, not from an already variance-scaled bound.
    data = %{
      state.mob_data
      | level: runtime_level(state),
        stats: Map.take(base, [:str, :agi, :vit, :int, :dex, :luk])
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
