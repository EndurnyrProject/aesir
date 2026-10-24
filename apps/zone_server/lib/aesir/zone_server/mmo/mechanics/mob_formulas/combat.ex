defmodule Aesir.ZoneServer.Mmo.Mechanics.MobFormulas.Combat do
  @moduledoc false

  import Aesir.ZoneServer.Mmo.Mechanics.MobFormulas, only: [fixed: 3, value: 3]

  alias Aesir.ZoneServer.Mmo.StatusEffect.CalcFlags
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.Mob.Calculated
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @doc false
  @spec recalculate(MobState.t(), [StatusEntry.t()], [CalcFlags.flag()], :renewal | :pre_renewal) ::
          Calculated.t()
  def recalculate(state, entries, flags, mode) do
    entries = Map.new(entries, &{&1.type, &1})
    base = state.base
    calculated = state.calculated

    calculated =
      Enum.reduce(
        [
          {"Str", :str},
          {"Agi", :agi},
          {"Vit", :vit},
          {"Int", :int},
          {"Dex", :dex},
          {"Luk", :luk}
        ],
        calculated,
        fn {flag, field}, calculated ->
          if flag in flags do
            Map.put(calculated, field, primary(field, Map.fetch!(base, field), entries, mode))
          else
            calculated
          end
        end
      )

    calculated =
      if "Batk" in flags and base.batk != 0 do
        level = MobState.get_level(state)
        attack = base_attack(calculated.str, level, mode)
        residual = base.batk - base_attack(base.str, level, mode)
        attack = attack + residual + value(entries, :sc_volcano, :val2)
        attack = if mode == :renewal, do: attack + fixed(entries, :sc_loud, 30), else: attack

        attack =
          if mode == :renewal and value(entries, :sc_nibelungen, :val2) == 2,
            do: attack + div(attack * 20, 100),
            else: attack

        %{calculated | batk: Integer.mod(attack + 2_147_483_648, 4_294_967_296) - 2_147_483_648}
      else
        calculated
      end

    calculated = recalculate_weapons(base, calculated, entries, flags, mode)

    calculated =
      recalculate_accuracy(base, calculated, entries, flags, mode, [
        {"Hit", :hit},
        {"Flee", :flee}
      ])

    calculated = recalculate_defenses(base, calculated, entries, flags, mode)

    calculated =
      recalculate_accuracy(base, calculated, entries, flags, mode, [
        {"Cri", :cri},
        {"Flee2", :flee2}
      ])

    if "Matk" in flags do
      {minimum, maximum} = magic_bounds(state, calculated, entries, mode)
      %{calculated | matk_min: minimum, matk_max: maximum}
    else
      calculated
    end
  end

  defp recalculate_weapons(base, calculated, entries, flags, mode) do
    if "Watk" in flags do
      case mode do
        :pre_renewal ->
          %{
            calculated
            | watk_min: weapon_attack(base.watk_min, entries, mode),
              watk_max: weapon_attack(base.watk_max, entries, mode)
          }

        :renewal when base.watk == 0 ->
          %{calculated | watk: 0, watk2: weapon_attack(base.watk2, entries, mode)}

        :renewal ->
          %{calculated | watk: weapon_attack(base.watk, entries, mode)}
      end
    else
      calculated
    end
  end

  defp weapon_attack(base, entries, mode) do
    attack =
      base + value(entries, :sc_impositio, :val2) + value(entries, :sc_watkfood, :val1) +
        value(entries, :sc_volcano, :val2)

    attack =
      if mode == :pre_renewal,
        do:
          attack + value(entries, :sc_drumbattle, :val2) + value(entries, :sc_nibelungen, :val2),
        else: attack

    min(max(attack, 0), 65_535)
  end

  defp magic_bounds(state, calculated, entries, mode) do
    int = calculated.int
    level = MobState.get_level(state)

    {minimum, maximum} =
      case mode do
        :renewal ->
          {int + level + div(state.mob_data.matk * 70, 100),
           int + level + div(state.mob_data.matk * 130, 100)}

        :pre_renewal ->
          {int + div(int, 7) * div(int, 7), int + div(int, 5) * div(int, 5)}
      end

    rate = magic_power(entries, mode)

    flat =
      if mode == :renewal,
        do: value(entries, :sc_impositio, :val2) + value(entries, :sc_volcano, :val2),
        else: 0

    calculate = fn value ->
      value = Integer.mod(value, 65_536)
      value = value + div(value * rate, 100) + flat
      min(max(value, 0), 65_535)
    end

    {calculate.(minimum), calculate.(maximum)}
  end

  defp magic_power(entries, mode) do
    case entries[:sc_magicpower] do
      nil ->
        0

      entry ->
        if mode == :renewal or entry.val4 != 0 or Map.get(entry.state || %{}, :armed, false),
          do: entry.val3,
          else: 0
    end
  end

  defp recalculate_defenses(base, calculated, entries, flags, mode) do
    Enum.reduce(
      [{"Def", :def}, {"Def2", :def2}, {"Mdef", :mdef}, {"Mdef2", :mdef2}],
      calculated,
      fn {flag, field}, calculated ->
        if flag in flags do
          Map.put(calculated, field, defense(field, base, calculated, entries, mode))
        else
          calculated
        end
      end
    )
  end

  defp defense(:def, base, _calculated, entries, mode) do
    cond do
      mode == :renewal and Map.has_key?(entries, :sc_eternalchaos) -> 0
      mode == :pre_renewal and Map.has_key?(entries, :sc_steelbody) -> 90
      true -> hard_defense(base.def, entries, mode)
    end
  end

  defp defense(:def2, base, calculated, entries, mode) do
    if Map.has_key?(entries, :sc_eternalchaos) do
      0
    else
      defense = base.def2 + defense_delta(base, calculated, mode)
      angelus_base = if mode == :renewal, do: div(calculated.vit, 2), else: defense
      defense = defense + div(angelus_base * value(entries, :sc_angelus, :val2), 100)

      defense =
        if mode == :pre_renewal,
          do: defense - div(defense * value(entries, :sc_concentration, :val4), 100),
          else: defense

      defense = poison_defense(defense, entries)
      defense = defense - div(defense * value(entries, :sc_provoke, :val3), 100)
      wounds = value(entries, :sc_jointbeat, :val2)
      shoulder = if Bitwise.band(wounds, 0x08) != 0, do: div(defense * 50, 100), else: 0
      waist = if Bitwise.band(wounds, 0x10) != 0, do: div(defense * 25, 100), else: 0
      clamp_soft(defense - shoulder - waist, mode)
    end
  end

  defp defense(:mdef, base, _calculated, entries, mode) do
    if mode == :pre_renewal and Map.has_key?(entries, :sc_steelbody) do
      90
    else
      endure =
        if value(entries, :sc_endure, :val4) == 0, do: value(entries, :sc_endure, :val1), else: 1

      endure = if value(entries, :sc_endure, :val3) == 0, do: endure, else: 0
      defense = base.mdef + endure
      defense = defense + div(defense * fixed(entries, :sc_stone, 25), 100)
      defense = defense + div(defense * fixed(entries, :sc_freeze, 25), 100)
      clamp_hard(defense, mode)
    end
  end

  defp defense(:mdef2, base, calculated, entries, mode) do
    defense = base.mdef2 + calculated.int - base.int + magic_defense_delta(base, calculated, mode)
    defense = defense - div(defense * value(entries, :sc_mindbreaker, :val3), 100)
    clamp_soft(defense, mode)
  end

  defp hard_defense(base, entries, mode) do
    defense = base + value(entries, :sc_drumbattle, :val3)

    defense =
      if mode == :renewal, do: defense + value(entries, :sc_assumptio, :val1) * 50, else: defense

    defense = defense + div(defense * value(entries, :sc_incdefrate, :val1), 100)
    defense = if Map.has_key?(entries, :sc_stone), do: div(defense, 2), else: defense
    defense = if Map.has_key?(entries, :sc_freeze), do: div(defense, 2), else: defense
    defense = poison_defense(defense, entries)
    defense = defense - div(defense * value(entries, :sc_signumcrucis, :val2), 100)
    defense = defense - div(defense * value(entries, :sc_concentration, :val4), 100)
    defense = defense - div(defense * value(entries, :sc_provoke, :val3), 100)
    defense = defense - div(defense * value(entries, :sc_stripshield, :val2), 100)
    clamp_hard(defense, mode)
  end

  defp poison_defense(defense, entries) do
    if Map.has_key?(entries, :sc_poison) or Map.has_key?(entries, :sc_dpoison),
      do: div(defense * 75, 100),
      else: defense
  end

  defp defense_delta(base, calculated, :renewal) do
    trunc(
      float32(float_delta(calculated.vit, base.vit, 2) + float_delta(calculated.agi, base.agi, 5))
    )
  end

  defp defense_delta(base, calculated, :pre_renewal), do: calculated.vit - base.vit

  defp magic_defense_delta(base, calculated, :renewal) do
    trunc(
      float32(float_delta(calculated.dex, base.dex, 5) + float_delta(calculated.vit, base.vit, 5))
    )
  end

  defp magic_defense_delta(base, calculated, :pre_renewal), do: div(calculated.vit - base.vit, 2)

  defp float_delta(value, base, divisor),
    do: float32(float32(value / divisor) - float32(base / divisor))

  defp float32(value) do
    <<rounded::float-32>> = <<value::float-32>>
    rounded
  end

  defp clamp_hard(value, :renewal), do: min(max(value, -32_768), 32_767)
  defp clamp_hard(value, :pre_renewal), do: min(max(value, -128), 127)
  defp clamp_soft(value, :renewal), do: min(max(value, -32_768), 32_767)
  defp clamp_soft(value, :pre_renewal), do: min(max(value, 1), 32_767)

  defp recalculate_accuracy(base, calculated, entries, flags, mode, fields) do
    Enum.reduce(
      fields,
      calculated,
      fn {flag, field}, calculated ->
        guarded_zero? = field in [:cri, :flee2] and Map.fetch!(base, field) == 0

        if flag in flags and not guarded_zero? do
          Map.put(calculated, field, accuracy(field, base, calculated, entries, mode))
        else
          calculated
        end
      end
    )
  end

  defp accuracy(:hit, base, calculated, entries, mode) do
    luk = if mode == :renewal, do: div(calculated.luk, 3) - div(base.luk, 3), else: 0
    hit = base.hit + calculated.dex - base.dex + luk

    hit =
      hit + value(entries, :sc_inchit, :val1) + value(entries, :sc_truesight, :val3) +
        value(entries, :sc_humming, :val2) + value(entries, :sc_concentration, :val3)

    hit = hit + div(hit * value(entries, :sc_inchitrate, :val1), 100)
    hit = hit - div(hit * fixed(entries, :sc_blind, 25), 100)
    hit = if mode == :renewal, do: hit + renewal_hit_bonus(entries), else: hit
    min(max(hit, 1), 32_767)
  end

  defp accuracy(:flee, base, calculated, entries, mode) do
    luk = if mode == :renewal, do: div(calculated.luk, 5) - div(base.luk, 5), else: 0
    flee = base.flee + calculated.agi - base.agi + luk

    flee =
      flee + value(entries, :sc_incflee, :val1) + value(entries, :sc_whistle, :val2) +
        value(entries, :sc_windwalk, :val2) + value(entries, :sc_violentgale, :val2) +
        value(entries, :sc_closeconfine, :val3) + fixed(entries, :sc_speed, 10) +
        value(entries, :sc_speed, :val1) * 10

    flee =
      if mode == :renewal,
        do:
          flee + value(entries, :sc_spearquicken, :val1) * 2 +
            if(value(entries, :sc_nibelungen, :val2) == 8, do: 50, else: 0),
        else: flee

    flee = flee + div(flee * value(entries, :sc_incfleerate, :val1), 100)
    flee = flee + div(flee * value(entries, :sc_agiup, :val2), 100)
    flee = flee - div(flee * fixed(entries, :sc_spiderweb, 50), 100)
    flee = flee - div(flee * fixed(entries, :sc_blind, 25), 100)
    min(max(flee, 1), 32_767)
  end

  defp accuracy(:cri, base, calculated, entries, mode) do
    difference = calculated.luk - base.luk
    difference = if mode == :renewal, do: 3 * difference, else: div(difference * 10, 3)

    critical =
      base.cri + difference + value(entries, :sc_explosionspirits, :val2) +
        value(entries, :sc_fortunekiss, :val2) + value(entries, :sc_truesight, :val2)

    critical = if Map.has_key?(entries, :sc_cloaking), do: critical * 2, else: critical

    critical =
      if mode == :renewal,
        do:
          critical + value(entries, :sc_spearquicken, :val1) * 30 +
            fixed(entries, :sc_twohandquicken, 20) +
            value(entries, :sc_twohandquicken, :val1) * 10,
        else: critical

    min(max(critical, 10), 32_767)
  end

  defp accuracy(:flee2, base, calculated, entries, _mode) do
    flee = base.flee2 + calculated.luk - base.luk + value(entries, :sc_whistle, :val3)
    min(max(flee, 10), 32_767)
  end

  defp renewal_hit_bonus(entries) do
    value(entries, :sc_blessing, :val1) * 2 + value(entries, :sc_twohandquicken, :val1) * 2 +
      value(entries, :sc_adrenaline, :val1) * 3 + fixed(entries, :sc_adrenaline, 5) +
      if(value(entries, :sc_nibelungen, :val2) == 7, do: 50, else: 0)
  end

  defp primary(:luk, _base, entries, _mode) when is_map_key(entries, :sc_curse), do: 0

  defp primary(field, base, entries, mode) do
    bonus = if mode == :renewal and value(entries, :sc_nibelungen, :val2) == 6, do: 15, else: 0
    value = calculate_primary(field, base, entries) + bonus
    value = min(max(value, 0), 65_535)
    Integer.mod(value + 32_768, 65_536) - 32_768
  end

  defp calculate_primary(:str, base, entries) do
    value =
      base + value(entries, :sc_incallstatus, :val1) + fixed(entries, :sc_battleorder, 5) +
        value(entries, :sc_gd_leadership, :val1) + fixed(entries, :sc_loud, 4) +
        fixed(entries, :sc_truesight, 5)

    blessing(value, entries)
  end

  defp calculate_primary(:agi, base, entries) do
    concentrate(base, entries, :val3) + value(entries, :sc_incallstatus, :val1) +
      value(entries, :sc_gd_soulcold, :val1) + fixed(entries, :sc_truesight, 5) +
      value(entries, :sc_increaseagi, :val2) - value(entries, :sc_decreaseagi, :val2) -
      value(entries, :sc_quagmire, :val2)
  end

  defp calculate_primary(:vit, base, entries) do
    value =
      base + value(entries, :sc_incallstatus, :val1) + value(entries, :sc_change, :val2) +
        value(entries, :sc_gd_glorywounds, :val1) + fixed(entries, :sc_truesight, 5)

    value - div(value * value(entries, :sc_striparmor, :val2), 100)
  end

  defp calculate_primary(:int, base, entries) do
    value =
      base + value(entries, :sc_incallstatus, :val1) + value(entries, :sc_change, :val3) +
        fixed(entries, :sc_battleorder, 5) + fixed(entries, :sc_truesight, 5)

    value = blessing(value, entries)
    value - div(value * value(entries, :sc_striphelm, :val2), 100)
  end

  defp calculate_primary(:dex, base, entries) do
    value =
      concentrate(base, entries, :val4) + value(entries, :sc_incallstatus, :val1) +
        fixed(entries, :sc_battleorder, 5) + value(entries, :sc_gd_hawkeyes, :val1) +
        fixed(entries, :sc_truesight, 5) - value(entries, :sc_quagmire, :val2)

    blessing(value, entries)
  end

  defp calculate_primary(:luk, base, entries) do
    base + value(entries, :sc_incallstatus, :val1) + fixed(entries, :sc_truesight, 5) +
      fixed(entries, :sc_gloria, 30)
  end

  defp concentrate(base, entries, field) do
    if Map.has_key?(entries, :sc_quagmire) do
      base
    else
      base +
        div(
          (base - value(entries, :sc_concentrate, field)) * value(entries, :sc_concentrate, :val2),
          100
        )
    end
  end

  defp blessing(value, entries) do
    case entries[:sc_blessing] do
      nil -> value
      %{val2: 0} -> value - div(value, 2)
      %{val2: bonus} -> value + bonus
    end
  end

  defp base_attack(str, level, :renewal), do: min(max(str + level, 0), 65_535)
  defp base_attack(_str, _level, :pre_renewal), do: 0
end
