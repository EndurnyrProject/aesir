defmodule Aesir.ZoneServer.Integration.CastSweepTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :integration
  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Homunculus
  alias Aesir.Net.GroundSkillCast
  alias Aesir.Net.HomunculusCastSkillCommand
  alias Aesir.Net.HomunculusRequest
  alias Aesir.Net.HomunculusResult
  alias Aesir.Net.MapLoaded
  alias Aesir.Net.SkillCast
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Skill.Castability
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @map "cast_sweep_map"
  @caster_mob_id 1_002
  @compatible_assassin_skill_ids MapSet.new([135, 136, 137, 140, 141])

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

  skills =
    :zone_server
    |> Application.app_dir("priv/db/re/mob_skills/mob_skills.yml")
    |> YamlElixir.read_from_file!()
    |> Map.values()
    |> List.flatten()
    |> Enum.map(coerce_row)
    |> Enum.uniq_by(& &1.skill_id)
    |> Enum.flat_map(fn row ->
      with {:ok, definition} <- Catalog.by_id(row.skill_id),
           {:ok, _module} <- Catalog.active_module_for(definition.name) do
        [{definition, row}]
      else
        :error -> []
      end
    end)

  @skills skills

  test "the mob sweep includes every compatible imported Assassin definition" do
    swept_ids = @skills |> Enum.map(fn {definition, _row} -> definition.id end) |> MapSet.new()

    assert MapSet.subset?(@compatible_assassin_skill_ids, swept_ids)

    Enum.each(@compatible_assassin_skill_ids, fn skill_id ->
      assert {:ok, definition} = Catalog.by_id(skill_id)
      assert :ok = Castability.check(definition, :mob)
    end)
  end

  test "mob declarations match execution through live MobSessions" do
    Enum.each(@skills, fn {definition, row} ->
      case Castability.check(definition, :mob) do
        {:error, {:missing, [_requirement | _rest]}} = error ->
          assert {:error, _reason} = error

        :ok ->
          target = spawn_test_mob(@map, {151, 150}, mob_id: @caster_mob_id, max_hp: 1_000_000)
          caster = spawn_test_mob(@map, {150, 150}, mob_id: @caster_mob_id, max_hp: 1_000_000)

          :sys.replace_state(caster.pid, fn state ->
            state
            |> MobState.set_target(target.unit_id)
            |> Map.put(:target_ref, {:mob, target.unit_id})
            |> Map.put(:master_id, target.unit_id)
            |> MobState.set_casting(%{row: row, complete_at: 0, timer_ref: nil})
          end)

          send(caster.pid, {:casting, :complete})
          assert %MobState{casting: nil} = :sys.get_state(caster.pid)
      end
    end)
  end

  test "player declarations match execution through live PlayerSessions" do
    Enum.each(@skills, fn {definition, row} ->
      assert :ok = Castability.check(definition, :player)

      level = min(row.level, definition.max_level)
      target = spawn_test_mob(@map, {151, 150}, mob_id: @caster_mob_id, max_hp: 1_000_000)

      player =
        start_player_session(
          map_name: @map,
          position: {150, 150},
          base_level: 99,
          job_level: 70,
          hp: 1_000_000,
          max_hp: 1_000_000,
          sp: 1_000_000,
          max_sp: 1_000_000,
          zeny: 1_000_000,
          learned_skills: %{Integer.to_string(definition.id) => level}
        )

      packet =
        if definition.target_type == :ground do
          %GroundSkillCast{skill_id: definition.id, level: level, x: 151, y: 150}
        else
          %SkillCast{skill_id: definition.id, level: level, target_id: target.unit_id}
        end

      simulate_incoming_message(player.pid, packet)
      assert %{game_state: _game_state} = PlayerSession.get_state(player.pid)
      end_player_session(player)
    end)
  end

  test "homunculus declarations match execution through its owning PlayerSession" do
    owner = start_homunculus_owner()
    target = spawn_test_mob(@map, {151, 150}, mob_id: @caster_mob_id, max_hp: 1_000_000)

    Enum.with_index(@skills, 1)
    |> Enum.each(fn {{definition, row}, request_id} ->
      case Castability.check(definition, :homunculus) do
        {:error, {:missing, [_requirement | _rest]}} = error ->
          assert {:error, _reason} = error

        :ok ->
          simulate_incoming_message(owner.pid, %HomunculusRequest{
            request_id: request_id,
            command:
              {:cast_skill,
               %HomunculusCastSkillCommand{
                 skill_id: definition.id,
                 level: min(row.level, definition.max_level),
                 target: {:target_id, target.unit_id}
               }}
          })

          assert_receive {:packet_sent, %HomunculusResult{request_id: ^request_id}, _}, 1_000
          assert %{homunculus: _homunculus} = PlayerSession.get_state(owner.pid)
      end
    end)
  end

  defp start_homunculus_owner do
    suffix = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        userid: "cast_sweep_#{suffix}",
        user_pass: "password",
        email: "cast-sweep-#{suffix}@example.com"
      })
      |> Repo.insert!()

    character =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Sweep#{suffix}",
        class: 5,
        base_level: 99,
        job_level: 70,
        hp: 1_000_000,
        max_hp: 1_000_000,
        sp: 1_000_000,
        max_sp: 1_000_000,
        learned_skills: %{},
        last_map: @map,
        last_x: 150,
        last_y: 150
      })
      |> Repo.insert!()

    %Homunculus{}
    |> Homunculus.changeset(%{
      character_id: character.id,
      class_id: 6_001,
      name: "SweepLif",
      lifecycle: "active",
      level: 99,
      skill_points: 0,
      hp: 1_000_000,
      max_hp: 1_000_000,
      sp: 1_000_000,
      max_sp: 1_000_000,
      str: 99,
      agi: 99,
      vit: 99,
      int: 99,
      dex: 99,
      luk: 99,
      hunger: 32,
      intimacy_hundredths: 75_100,
      active_remaining_ms: 1_800_000,
      learned_skills: %{},
      cooldowns: %{},
      ai_config: %{}
    })
    |> Repo.insert!()

    character = Repo.preload(character, :homunculus)
    owner = start_player_session(character: character, map_name: @map, position: {150, 150})
    simulate_incoming_message(owner.pid, %MapLoaded{})
    owner
  end
end
