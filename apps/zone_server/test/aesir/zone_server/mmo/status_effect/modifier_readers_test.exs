defmodule Aesir.ZoneServer.Mmo.StatusEffect.ModifierReadersTest do
  @moduledoc """
  Guards against dead modifier keys: a status effect whose `modifiers/2`
  returns a key nothing in `lib/` reads silently does nothing (Aspersio,
  Enchant Poison and Benedictio all shipped that way). Emitted keys are
  extracted statically from every effect module's `modifiers/2` body and
  checked against the curated inventory of keys the engine actually reads.

  When this test fails, either the new key needs a reader wired into the
  engine, or the effect should emit one of the existing read keys.
  """
  use ExUnit.Case, async: true

  @effects_dir Path.join(
                 __DIR__,
                 "../../../../../lib/aesir/zone_server/mmo/status_effect/effects"
               )

  # Every modifier key with at least one reader in lib/. Grouped by reader.
  @read_keys MapSet.new([
               # Stats.get_effective_stat/2 (base + trait stats)
               :str,
               :agi,
               :vit,
               :int,
               :dex,
               :luk,
               :pow,
               :sta,
               :wis,
               :spl,
               :con,
               :crt,
               # Stats.get_status_modifier/2 call sites + MobState.to_combatant
               :hit,
               :flee,
               :atk,
               :def,
               :matk,
               :mdef,
               :aspd,
               :aspd_rate,
               :critical,
               :critical_rate,
               :perfect_dodge,
               :movement_speed,
               :walk_speed_override,
               :aspd_penalty_rate,
               :regen_interval_multiplier,
               :max_hp_rate,
               :max_sp_rate,
               # DamageCalculator / MagicDamageCalculator / DamageShared
               :atk_bonus,
               :atk_rate,
               :attack_element,
               :damage_bonus,
               :damage_multiplier,
               :def_bonus,
               :def_rate,
               :def2_rate,
               :defense_multiplier,
               :element_override,
               :magic_damage_reduction,
               :matk_rate,
               :max_weapon_damage,
               :mdef_rate,
               :phys_damage_reduction,
               :vit_bonus,
               :watk,
               # EquipmentBonuses taken families (status → damage-taken/resist bridge)
               :ranged_damage_taken_rate,
               :subele_water,
               :subele_earth,
               :subele_fire,
               :subele_wind,
               :subele_holy,
               :subrace_demon,
               # NaturalHeal / handlers / Skill.Interpreter / Script.Dsl
               :hp_regen,
               :sp_regen,
               :exp_rate,
               :job_exp_rate,
               :drop_rate,
               :received_heal_rate,
               :no_death_penalty,
               :sp_cost_rate,
               :varcast_rate,
               :ailment_resist_rate
             ])

  # Tuple-shaped keys read by the damage calculators.
  @read_tuple_tags [:element_ratio, :magic_addsize, :magic_addrace]

  test "every key emitted by an effect's modifiers/2 has a reader" do
    dead =
      @effects_dir
      |> Path.join("*.ex")
      |> Path.wildcard()
      |> Enum.flat_map(fn file ->
        file
        |> emitted_keys()
        |> Enum.reject(&read?/1)
        |> Enum.map(&{Path.basename(file), &1})
      end)

    assert dead == [],
           "modifier keys with no reader in lib/ (wire a reader or emit a read key): " <>
             inspect(dead)
  end

  defp read?(key) when is_atom(key), do: MapSet.member?(@read_keys, key)
  defp read?({tag, _}) when is_atom(tag), do: tag in @read_tuple_tags
  defp read?(_), do: false

  defp emitted_keys(file) do
    file
    |> File.read!()
    |> Code.string_to_quoted!()
    |> modifier_bodies()
    |> Enum.flat_map(&map_keys/1)
    |> Enum.uniq()
  end

  defp modifier_bodies(ast) do
    {_, bodies} =
      Macro.prewalk(ast, [], fn
        {:def, _, [{:modifiers, _, _} | _] = clause} = node, acc ->
          {node, [clause_body(clause) | acc]}

        node, acc ->
          {node, acc}
      end)

    bodies
  end

  defp clause_body([_head, [do: body]]), do: body
  defp clause_body(_), do: nil

  defp map_keys(nil), do: []

  defp map_keys(body) do
    {_, keys} =
      Macro.prewalk(body, [], fn
        {:%{}, _, pairs} = node, acc when is_list(pairs) ->
          {node, Enum.map(pairs, &literal_key/1) ++ acc}

        node, acc ->
          {node, acc}
      end)

    keys |> Enum.reject(&is_nil/1)
  end

  defp literal_key({key, _value}) when is_atom(key), do: key

  defp literal_key({{:{}, _, [tag, elem]}, _value}) when is_atom(tag) and is_atom(elem),
    do: {tag, elem}

  defp literal_key({{tag, elem}, _value}) when is_atom(tag) and is_atom(elem), do: {tag, elem}

  defp literal_key(_), do: nil
end
