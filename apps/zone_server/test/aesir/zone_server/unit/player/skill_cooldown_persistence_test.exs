defmodule Aesir.ZoneServer.Unit.Player.SkillCooldownPersistenceTest do
  use Aesir.DataCase, async: false

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.CharacterSkillCooldown
  alias Aesir.Net.SkillCooldown
  alias Aesir.ZoneServer.Mmo.Homunculus.LifecycleSkills
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SkillCooldownPersistence
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @fire_bolt 19
  @urgent_call 10_013

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "cooldownuser",
        user_pass: "password",
        sex: "M",
        email: "cooldown@example.com"
      })
      |> Repo.insert()

    {:ok, character} =
      %{account_id: account.id, char_num: 0, name: "CooldownChar", class: 0, base_level: 1}
      |> Character.new()
      |> Repo.insert()

    game_state = PlayerState.new(character)
    :ok = UnitRegistry.register_player(game_state, self())
    %{game_state: game_state}
  end

  defp with_cooldowns(game_state, cooldowns) do
    now = System.monotonic_time(:millisecond)
    %{game_state | skill_cooldowns: Map.new(cooldowns, fn {id, left} -> {id, now + left} end)}
  end

  defp saved, do: Map.new(Repo.all(CharacterSkillCooldown), &{&1.skill_id, &1.remaining_ms})

  @tag game_mode: :renewal
  test "renewal saves every running cooldown's remaining time, guild skills included", %{
    game_state: game_state
  } do
    game_state
    |> with_cooldowns(%{@fire_bolt => 60_000, @urgent_call => 200_000, 14 => -5})
    |> SkillCooldownPersistence.save_cooldowns()

    assert %{@fire_bolt => fire_bolt, @urgent_call => urgent_call} = saved = saved()
    assert map_size(saved) == 2
    assert fire_bolt in 59_000..60_000
    assert urgent_call in 199_000..200_000
  end

  @tag game_mode: :pre_renewal
  test "pre-renewal does not save guild skill cooldowns", %{game_state: game_state} do
    game_state
    |> with_cooldowns(%{@fire_bolt => 60_000, @urgent_call => 200_000})
    |> SkillCooldownPersistence.save_cooldowns()

    assert Map.keys(saved()) == [@fire_bolt]
  end

  test "Homunculus lifecycle cooldowns are left to the Homunculus record", %{
    game_state: game_state
  } do
    game_state
    |> with_cooldowns(Map.new(LifecycleSkills.ids(), &{&1, 60_000}))
    |> SkillCooldownPersistence.save_cooldowns()

    assert saved() == %{}
  end

  test "login resumes each cooldown for its remaining time, shows it and consumes the rows", %{
    game_state: game_state
  } do
    Repo.insert_all(CharacterSkillCooldown, [
      %{char_id: game_state.character_id, skill_id: @fire_bolt, remaining_ms: 45_000}
    ])

    before = System.monotonic_time(:millisecond)

    restored =
      SkillCooldownPersistence.restore_on_spawn(%{connection_pid: self(), game_state: game_state})

    expires_at = restored.game_state.skill_cooldowns[@fire_bolt]
    assert expires_at >= before + 45_000
    assert expires_at <= System.monotonic_time(:millisecond) + 45_000

    assert_received {:send, :gameplay,
                     {:skill_cooldown, %SkillCooldown{skill_id: @fire_bolt, tick: 45_000}}}

    assert saved() == %{}

    assert {:ok, {_module, registered, _pid}} =
             UnitRegistry.get_unit(:player, game_state.character_id)

    assert registered.skill_cooldowns[@fire_bolt] == expires_at
  end

  test "a login with nothing saved changes nothing", %{game_state: game_state} do
    state = %{connection_pid: self(), game_state: game_state}

    assert SkillCooldownPersistence.restore_on_spawn(state) == state
    refute_received {:send, _channel, {:skill_cooldown, _}}
  end
end
