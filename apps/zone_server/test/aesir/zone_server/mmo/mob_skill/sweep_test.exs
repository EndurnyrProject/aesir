defmodule Aesir.ZoneServer.Mmo.MobSkill.SweepTest do
  @moduledoc """
  Safety-gate sweep: every distinct (skill, skill id) pair shipped in
  `priv/db/mob_skills/mob_skills.yml` is exercised against a real, registered
  mob caster through the real `Executor`, end to end. This is what makes "free
  coverage" (any player skill the catalog resolves becomes castable by a mob)
  safe: a crash here means a live mob would crash its `MobSession`.

  Data is read straight from the YAML file at compile time (not through
  `MobSkill.Db`, which requires a known `MobDefinition` per mob id and would
  silently drop rows belonging to mobs absent from the seeded mob db). One
  `test` is generated per distinct `{skill, skill_id}` pair so a failure names
  the culprit skill directly; each test classifies its skill id the same way
  `Selector.castable?/1` does:

    * unresolved (no catalog entry, or no active module) - asserts nothing,
      only counted (see the `"coverage summary"` test).
    * denylisted - asserts `Denylist.reason_for/1` returns a reason.
    * castable - runs every distinct target-code row shipped for that skill
      through `Executor.execute/2` against a live mob caster (with a
      player/friend/master target as the row's target code needs) and
      asserts a clean `:ok` or `{:error, atom}` result, never a crash. Also
      asserts the id<->name join holds (`definition.name` upcased equals the
      row's `skill` string), except for two documented upstream label/id
      mismatches (see `@known_label_id_mismatches`).
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.ZoneServer.Mmo.MobSkill.Denylist
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.Skill.Catalog, as: SkillCatalog

  @external_resource Application.app_dir(:zone_server, "priv/db/mob_skills/mob_skills.yml")

  @map "prontera"
  @caster_mob_id 1002

  # rAthena's mob_skill_db.txt carries a skill's numeric id and its `@NAME`
  # label as two independent columns (see `MobSkill.Importer`'s moduledoc); on
  # exactly 3 rows (the ILL_GHOUL/ILL_MUNAK/ILL_BON_GUN event mobs) the two
  # disagree - the id dispatches to a *different* skill than the label names.
  # Verified against the shipped data: not a bug in our code, and not
  # castable-safety related (the id-resolved skill still casts cleanly).
  # Excluded here from the id<->name join only, not from the cast sweep.
  @known_label_id_mismatches MapSet.new([{"NPC_TALK", 196}, {"NPC_BLOODDRAIN", 176}])

  coerce_value = fn
    value when is_binary(value) -> String.to_atom(value)
    value -> value
  end

  coerce_row = fn row ->
    condition = row["condition"]

    %{
      skill: row["skill"],
      skill_id: row["skill_id"],
      state: String.to_atom(row["state"]),
      level: row["level"],
      rate: row["rate"],
      cast_time: row["cast_time"],
      delay: row["delay"],
      cancelable: row["cancelable"],
      target: String.to_atom(row["target"]),
      condition: %{
        type: String.to_atom(condition["type"]),
        value: coerce_value.(condition["value"]),
        val1: condition["val1"],
        val2: condition["val2"],
        val3: condition["val3"],
        val4: condition["val4"],
        val5: condition["val5"]
      },
      emotion: row["emotion"]
    }
  end

  by_skill =
    Application.app_dir(:zone_server, "priv/db/mob_skills/mob_skills.yml")
    |> YamlElixir.read_from_file!()
    |> Map.values()
    |> List.flatten()
    |> Enum.map(coerce_row)
    |> Enum.group_by(&{&1.skill, &1.skill_id})
    |> Map.new(fn {key, rows} ->
      representatives =
        rows
        |> Enum.group_by(& &1.target)
        |> Enum.map(fn {_target, target_rows} -> Enum.max_by(target_rows, & &1.level) end)

      {key, representatives}
    end)

  @by_skill by_skill

  setup do
    player =
      start_player_session(
        base_level: 60,
        map_name: @map,
        position: {150, 150},
        hp: 60_000,
        max_hp: 60_000,
        sp: 6_000,
        max_sp: 6_000
      )

    %{player: player}
  end

  test "coverage summary" do
    tally =
      Enum.reduce(@by_skill, %{castable: 0, denylisted: 0, unresolved: 0}, fn {{_skill, id}, _},
                                                                              acc ->
        Map.update!(acc, classify(id), &(&1 + 1))
      end)

    IO.puts(
      "[MobSkill sweep] #{map_size(@by_skill)} distinct skills - " <>
        "castable: #{tally.castable}  denylisted: #{tally.denylisted}  " <>
        "unresolved: #{tally.unresolved}"
    )

    assert tally.castable + tally.denylisted + tally.unresolved == map_size(@by_skill)
  end

  for {{skill, skill_id}, target_rows} <- @by_skill do
    target_list = target_rows |> Enum.map(& &1.target) |> Enum.sort()

    test "#{skill} (id #{skill_id}) targets=#{inspect(target_list)}", %{player: player} do
      exercise_skill(
        unquote(skill),
        unquote(skill_id),
        unquote(Macro.escape(target_rows)),
        player
      )
    end
  end

  defp exercise_skill(skill, skill_id, target_rows, player) do
    case classify(skill_id) do
      :unresolved ->
        :ok

      :denylisted ->
        assert Denylist.reason_for(skill_id) != nil

      :castable ->
        assert_id_name_match(skill, skill_id)

        caster_mob = spawn_test_mob(@map, {152, 150}, mob_id: @caster_mob_id)

        Enum.each(target_rows, fn row ->
          caster = build_caster(row.target, caster_mob, player)
          result = Executor.execute(caster, row)

          assert clean_result?(result),
                 "#{skill} (#{skill_id}) target=#{row.target} returned #{inspect(result)}"
        end)
    end
  end

  defp classify(skill_id) do
    with {:ok, definition} <- SkillCatalog.by_id(skill_id),
         {:ok, _module} <- SkillCatalog.active_module_for(definition.name) do
      if Denylist.denied?(skill_id), do: :denylisted, else: :castable
    else
      :error -> :unresolved
    end
  end

  defp assert_id_name_match(skill, skill_id) do
    if {skill, skill_id} not in @known_label_id_mismatches do
      {:ok, definition} = SkillCatalog.by_id(skill_id)

      assert definition.name |> Atom.to_string() |> String.upcase() == skill,
             "row skill=#{skill} id=#{skill_id} resolves to #{inspect(definition.name)}"
    end
  end

  defp clean_result?(:ok), do: true
  defp clean_result?({:error, reason}) when is_atom(reason), do: true
  defp clean_result?(_), do: false

  defp build_caster(target, caster_mob, player) when target in [:target, :randomtarget],
    do: %{get_mob_state(caster_mob.pid) | target_id: player.character.id}

  defp build_caster(:friend, caster_mob, _player) do
    {cx, cy} = caster_mob.position
    friend_mob = spawn_test_mob(@map, {cx + 1, cy}, mob_id: caster_mob.mob_id, hp: 50)
    %{get_mob_state(caster_mob.pid) | target_id: friend_mob.unit_id}
  end

  defp build_caster(:master, caster_mob, _player) do
    {cx, cy} = caster_mob.position
    master_mob = spawn_test_mob(@map, {cx + 1, cy}, mob_id: @caster_mob_id)
    %{get_mob_state(caster_mob.pid) | master_id: master_mob.unit_id}
  end

  defp build_caster(_around, caster_mob, _player), do: get_mob_state(caster_mob.pid)
end
