defmodule Aesir.ZoneServer.Unit.Homunculus.ItemEffectHandlerTest do
  use Aesir.DataCase, async: false
  use Mimic

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Homunculus
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.HomunculusPrivateState
  alias Aesir.Net.ItemRemoved
  alias Aesir.Net.ItemUseResult
  alias Aesir.ZoneServer.Mmo.Homunculus.Ai.Config
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.ItemEffectHandler
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.Persistence
  alias Aesir.ZoneServer.Unit.Homunculus.Runtime
  alias Aesir.ZoneServer.Unit.Homunculus.StateRestore
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @client_index 2
  @server_index 0
  @stone_id 12_040
  @supplement_id 100_371

  setup :verify_on_exit!
  setup :set_mimic_private

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    Mimic.copy(Repo)
    Mimic.copy(InventoryPersistence)

    suffix = System.unique_integer([:positive])
    username = "ihe#{suffix}"

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: username,
        userid: username,
        user_pass: "password",
        email: "ihe#{suffix}@example.com"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "IHE#{suffix}",
        class: 1,
        base_level: 99,
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 10
      })
      |> Repo.insert()

    %{character: character}
  end

  test "Stone consumes once, persists one seeded evolution, resets intimacy, and publishes", %{
    character: character
  } do
    session = session(character, @stone_id, %{intimacy_hundredths: 91_100, level: 42, exp: 123})
    Process.put(:rolls, 0)

    assert {:noreply, evolved_session} =
             ItemEffectHandler.handle(
               @client_index,
               @server_index,
               :homunculus_evolution,
               session,
               roll: fn min, _max ->
                 Process.put(:rolls, Process.get(:rolls) + 1)
                 min
               end
             )

    assert Process.get(:rolls) == 8
    assert evolved_session.homunculus.class_id == 6_009
    assert evolved_session.homunculus.intimacy_hundredths == 1_000
    assert evolved_session.homunculus.level == 42
    assert evolved_session.homunculus.exp == 123
    assert evolved_session.game_state.inventory[@server_index].amount == 1
    assert evolved_session.homunculus_runtime.private_dirty == false

    assert %Homunculus{class_id: 6_009, intimacy_hundredths: 1_000} =
             Persistence.load_for_character(character.id)

    assert [%InventoryItem{amount: 1}] = InventoryPersistence.load_inventory(character.id)
    assert_received {:send, :gameplay, {:item_removed, %ItemRemoved{amount: 1}}}
    assert_received {:send, :gameplay, {:item_use_result, %ItemUseResult{ok: true}}}

    assert_received {:send, :bulk,
                     {:homunculus_private_state, %HomunculusPrivateState{evolved: true}}}

    flush_messages()

    assert {:noreply, ^evolved_session} =
             ItemEffectHandler.handle(
               @client_index,
               @server_index,
               :homunculus_evolution,
               evolved_session,
               roll: fn _, _ -> flunk("repeat evolution must not roll") end
             )

    refute_receive _
    assert [%InventoryItem{amount: 1}] = InventoryPersistence.load_inventory(character.id)
  end

  test "Stone rejects every active, living, original, and Loyal boundary", %{character: character} do
    cases = [
      %{lifecycle: :rested},
      %{hp: 0},
      %{class_id: 6_009},
      %{intimacy_hundredths: 91_099}
    ]

    session = session(character, @stone_id, %{intimacy_hundredths: 91_100})

    Enum.each(cases, fn attrs ->
      invalid = %{session | homunculus: Map.merge(session.homunculus, attrs)}

      assert {:noreply, ^invalid} =
               ItemEffectHandler.handle(
                 @client_index,
                 @server_index,
                 :homunculus_evolution,
                 invalid,
                 roll: fn _, _ -> flunk("invalid evolution must not roll") end
               )
    end)

    refute_receive _
  end

  test "Supplement adds exactly 100 hundredths, caps, and requires an active living companion", %{
    character: character
  } do
    session = session(character, @supplement_id)

    assert {:noreply, increased} =
             ItemEffectHandler.handle(
               @client_index,
               @server_index,
               {:homunculus_intimacy, 100},
               session
             )

    assert increased.homunculus.intimacy_hundredths == 2_200
    assert Persistence.load_for_character(character.id).intimacy_hundredths == 2_200

    {:ok, _row} =
      character.id
      |> Persistence.load_for_character()
      |> Persistence.save_semantic(%{intimacy_hundredths: 99_950})

    near_cap = %{increased | homunculus: %{increased.homunculus | intimacy_hundredths: 99_950}}

    assert {:noreply, capped} =
             ItemEffectHandler.handle(
               @client_index,
               @server_index,
               {:homunculus_intimacy, 100},
               near_cap
             )

    assert capped.homunculus.intimacy_hundredths == 100_000
    assert Persistence.load_for_character(character.id).intimacy_hundredths == 100_000

    Enum.each([%{lifecycle: :rested}, %{hp: 0}], fn attrs ->
      invalid = %{capped | homunculus: Map.merge(capped.homunculus, attrs)}

      assert {:noreply, ^invalid} =
               ItemEffectHandler.handle(
                 @client_index,
                 @server_index,
                 {:homunculus_intimacy, 100},
                 invalid
               )
    end)

    detached = %{capped | homunculus: nil}

    assert {:noreply, ^detached} =
             ItemEffectHandler.handle(
               @client_index,
               @server_index,
               {:homunculus_intimacy, 100},
               detached
             )
  end

  test "inventory persistence failure rolls back before the Homunculus update", %{
    character: character
  } do
    session = session(character, @supplement_id)

    stub(InventoryPersistence, :update_item, fn %InventoryItem{}, %{amount: 1} ->
      {:error, :injected_inventory_failure}
    end)

    assert {:noreply, ^session} =
             ItemEffectHandler.handle(
               @client_index,
               @server_index,
               {:homunculus_intimacy, 100},
               session
             )

    assert [%InventoryItem{amount: 2}] = InventoryPersistence.load_inventory(character.id)
    assert Persistence.load_for_character(character.id).intimacy_hundredths == 2_100
    refute_receive _
  end

  test "missing inventory and Homunculus update failure leave both rows and memory unchanged", %{
    character: character
  } do
    session = session(character, @supplement_id)
    missing_item = put_in(session.game_state.inventory, %{})

    assert {:noreply, ^missing_item} =
             ItemEffectHandler.handle(
               @client_index,
               @server_index,
               {:homunculus_intimacy, 100},
               missing_item
             )

    stub(Repo, :update, fn
      %Ecto.Changeset{data: %Homunculus{}} = changeset, _opts ->
        {:error, Ecto.Changeset.add_error(changeset, :base, "injected failure")}

      changeset, opts ->
        Mimic.call_original(Repo, :update, [changeset, opts])
    end)

    assert {:noreply, ^session} =
             ItemEffectHandler.handle(
               @client_index,
               @server_index,
               {:homunculus_intimacy, 100},
               session
             )

    assert [%InventoryItem{amount: 2}] = InventoryPersistence.load_inventory(character.id)
    assert Persistence.load_for_character(character.id).intimacy_hundredths == 2_100
    refute_receive _
  end

  defp session(character, item_id, row_attrs \\ %{}, state_attrs \\ %{}) do
    row = insert_homunculus(character.id, row_attrs)
    {:ok, restored} = StateRestore.restore(row)
    gid = System.unique_integer([:positive])

    homunculus =
      restored
      |> Map.merge(%{
        world_gid: gid,
        owner_session_pid: self(),
        map_name: "task15_test",
        x: 10,
        y: 10
      })
      |> Map.merge(state_attrs)

    UnitRegistry.register_unit(:homunculus, gid, HomunculusState, homunculus, self())

    item = insert_inventory_item(character.id, item_id)

    %SessionState{
      connection_pid: self(),
      game_state: %PlayerState{
        character_id: character.id,
        account_id: character.account_id,
        map_name: "task15_test",
        x: 10,
        y: 10,
        dir: 0,
        inventory: %{@server_index => item}
      },
      homunculus: homunculus,
      homunculus_runtime: %Runtime{private_dirty: false}
    }
  end

  defp insert_homunculus(character_id, attrs) do
    defaults = %{
      character_id: character_id,
      class_id: 6_001,
      name: "Lif",
      lifecycle: "active",
      level: 1,
      exp: 0,
      skill_points: 0,
      hp: 100,
      max_hp: 100,
      sp: 50,
      max_sp: 50,
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      intimacy_hundredths: 2_100,
      active_remaining_ms: 1_800_000,
      learned_skills: %{},
      cooldowns: %{},
      ai_config: Config.default() |> Config.encode()
    }

    {:ok, row} =
      %Homunculus{}
      |> Homunculus.changeset(Map.merge(defaults, attrs))
      |> Repo.insert()

    row
  end

  defp insert_inventory_item(character_id, item_id) do
    %InventoryItem{}
    |> InventoryItem.changeset(%{char_id: character_id, nameid: item_id, amount: 2})
    |> Repo.insert!()
  end

  defp flush_messages do
    receive do
      _message -> flush_messages()
    after
      0 -> :ok
    end
  end
end
