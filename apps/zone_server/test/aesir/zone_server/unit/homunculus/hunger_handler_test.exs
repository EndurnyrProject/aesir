defmodule Aesir.ZoneServer.Unit.Homunculus.HungerHandlerTest do
  use Aesir.DataCase, async: true
  use Mimic

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Homunculus
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Homunculus.Ai.Config
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.HungerHandler
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.Persistence
  alias Aesir.ZoneServer.Unit.Homunculus.Runtime
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!
  setup :set_mimic_from_context

  setup do
    Mimic.copy(Persistence)
    Mimic.copy(Repo)
    :ok
  end

  setup do
    suffix = System.unique_integer([:positive])
    username = "hh#{suffix}"

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: username,
        userid: username,
        user_pass: "password",
        email: "hh#{suffix}@example.com"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "HH#{suffix}",
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

  test "pins every feeding intimacy band boundary" do
    assert Enum.map(0..10, &HungerHandler.intimacy_delta/1) == List.duplicate(50, 11)
    assert HungerHandler.intimacy_delta(11) == 100
    assert HungerHandler.intimacy_delta(25) == 100
    assert HungerHandler.intimacy_delta(26) == 75
    assert HungerHandler.intimacy_delta(75) == 75
    assert HungerHandler.intimacy_delta(76) == -5
    assert HungerHandler.intimacy_delta(90) == -5
    assert HungerHandler.intimacy_delta(91) == -50
    assert HungerHandler.intimacy_delta(100) == -50
  end

  test "pins every canonical intimacy grade boundary" do
    assert HungerHandler.grade(0) == :hate_with_passion
    assert HungerHandler.grade(399) == :hate_with_passion
    assert HungerHandler.grade(400) == :hate
    assert HungerHandler.grade(1_099) == :hate
    assert HungerHandler.grade(1_100) == :awkward
    assert HungerHandler.grade(10_099) == :awkward
    assert HungerHandler.grade(10_100) == :shy
    assert HungerHandler.grade(25_099) == :shy
    assert HungerHandler.grade(25_100) == :neutral
    assert HungerHandler.grade(75_099) == :neutral
    assert HungerHandler.grade(75_100) == :cordial
    assert HungerHandler.grade(91_099) == :cordial
    assert HungerHandler.grade(91_100) == :loyal
    assert HungerHandler.grade(100_000) == :loyal
  end

  test "uses critical and normal pre-tick delays" do
    assert HungerHandler.tick_delay(0) == 20_000
    assert HungerHandler.tick_delay(10) == 20_000
    assert HungerHandler.tick_delay(11) == 60_000
    assert HungerHandler.tick_delay(100) == 60_000
  end

  test "arms hunger only while online, active, and living" do
    active = state(%{hunger: 10})
    runtime = runtime()

    assert {:ok, ^active, armed} = HungerHandler.arm(active, runtime, timer_opts())
    assert is_reference(armed.hunger_timer_ref)
    assert_receive {:timer_started, ref, 20_000, :hunger_tick}
    assert ref == armed.hunger_timer_ref

    assert {:noop, _, stopped} =
             HungerHandler.arm(%{active | lifecycle: :rested}, armed, timer_opts())

    assert stopped.hunger_timer_ref == nil
    assert_receive {:timer_cancelled, ^ref}

    assert {:noop, _, _} = HungerHandler.arm(%{active | hp: 0}, runtime, timer_opts())

    assert {:noop, _, _} =
             HungerHandler.arm(active, %{runtime | clocks_online: false}, timer_opts())

    refute_receive {:timer_started, _ref, _delay, _event}
  end

  test "stale hunger refs do nothing and a premature current delivery rearms the remainder", %{
    character: character
  } do
    row = insert_homunculus(character.id, %{hunger: 11})
    active = state_from(row)
    current_ref = make_ref()
    runtime = runtime(%{hunger_timer_ref: current_ref})

    assert {:noop, ^active, ^runtime, %{}} =
             HungerHandler.tick(active, runtime, %{}, make_ref(), timer_opts())

    opts = timer_opts(timer_read: fn ^current_ref -> 1_234 end)

    assert {:ok, ^active, rearmed, %{}} =
             HungerHandler.tick(active, runtime, %{}, current_ref, opts)

    assert rearmed.hunger_timer_ref != current_ref
    assert_receive {:timer_cancelled, ^current_ref}
    assert_receive {:timer_started, new_ref, 1_234, :hunger_tick}
    assert new_ref == rearmed.hunger_timer_ref
    assert Persistence.load_for_character(character.id).hunger == 11
  end

  test "a current tick persists one hunger loss and rearms from the resulting hunger", %{
    character: character
  } do
    row = insert_homunculus(character.id, %{hunger: 11})
    active = state_from(row)
    current_ref = make_ref()
    runtime = runtime(%{hunger_timer_ref: current_ref})

    assert {:ok, next, rearmed, %{}} =
             HungerHandler.tick(active, runtime, %{}, current_ref, timer_opts())

    assert next.hunger == 10
    assert next.intimacy_hundredths == active.intimacy_hundredths
    assert Persistence.load_for_character(character.id).hunger == 10
    assert_receive {:timer_started, next_ref, 20_000, :hunger_tick}
    assert next_ref == rearmed.hunger_timer_ref
  end

  test "zero hunger starves by exactly one intimacy and deletes at zero", %{
    character: character
  } do
    row = insert_homunculus(character.id, %{hunger: 0, intimacy_hundredths: 101})
    active = state_from(row)
    ref = make_ref()
    runtime = runtime(%{hunger_timer_ref: ref})

    assert {:ok, starved, rearmed, %{}} =
             HungerHandler.tick(active, runtime, %{}, ref, timer_opts())

    assert starved.hunger == 0
    assert starved.intimacy_hundredths == 1
    assert Persistence.load_for_character(character.id).intimacy_hundredths == 1
    assert_receive {:timer_started, next_ref, 20_000, :hunger_tick}
    assert next_ref == rearmed.hunger_timer_ref

    row = Persistence.load_for_character(character.id)
    active = %{starved | intimacy_hundredths: 100}
    ref = make_ref()

    assert {:ok, nil, deleted_runtime, %{}} =
             HungerHandler.tick(
               active,
               %{rearmed | hunger_timer_ref: ref},
               %{},
               ref,
               timer_opts()
             )

    assert deleted_runtime.hunger_timer_ref == nil
    assert Persistence.load_for_character(character.id) == nil
    assert row.id == active.id
  end

  test "a current delivery revalidates lifecycle, life, and online ownership", %{
    character: character
  } do
    row = insert_homunculus(character.id, %{hunger: 20})
    active = state_from(row)

    for {state, runtime} <- [
          {%{active | lifecycle: :rested}, runtime()},
          {%{active | hp: 0}, runtime()},
          {active, runtime(%{clocks_online: false})}
        ] do
      ref = make_ref()

      assert {:noop, ^state, %{hunger_timer_ref: nil}, %{}} =
               HungerHandler.tick(
                 state,
                 %{runtime | hunger_timer_ref: ref},
                 %{},
                 ref,
                 timer_opts()
               )
    end

    assert Persistence.load_for_character(character.id).hunger == 20
  end

  test "a missing durable row leaves tick state unchanged and rearms", %{character: character} do
    row = insert_homunculus(character.id, %{hunger: 20})
    active = state_from(row)
    {:ok, _, nil} = Persistence.delete(row, %{})
    ref = make_ref()
    runtime = runtime(%{hunger_timer_ref: ref})

    assert {:error, :homunculus_not_found, ^active, rearmed, %{}} =
             HungerHandler.tick(active, runtime, %{}, ref, timer_opts())

    assert_receive {:timer_started, next_ref, 60_000, :hunger_tick}
    assert next_ref == rearmed.hunger_timer_ref
  end

  test "successful low-hunger feed replaces its timer with the resulting cadence", %{
    character: character
  } do
    row = insert_homunculus(character.id, %{hunger: 10})
    active = state_from(row)
    old_ref = make_ref()
    runtime = runtime(%{hunger_timer_ref: old_ref})
    inventory = inventory_with_item(character.id, 537, 1)

    assert {:ok, fed, rearmed, %{}} =
             HungerHandler.feed(active, runtime, inventory, timer_opts())

    assert fed.hunger == 20
    assert_receive {:timer_cancelled, ^old_ref}
    assert_receive {:timer_started, new_ref, 60_000, :hunger_tick}
    assert rearmed.hunger_timer_ref == new_ref
  end

  test "feeding resolves the species food, consumes one, and uses pre-feed hunger", %{
    character: character
  } do
    row = insert_homunculus(character.id, %{hunger: 90, intimacy_hundredths: 99_999})
    active = state_from(row)
    inventory = inventory_with_item(character.id, 537, 2)

    runtime = runtime()

    assert {:ok, fed, rearmed, persisted_inventory} =
             HungerHandler.feed(active, runtime, inventory, timer_opts())

    assert fed.hunger == 100
    assert_receive {:timer_started, new_ref, 60_000, :hunger_tick}
    assert rearmed.hunger_timer_ref == new_ref
    assert fed.intimacy_hundredths == 99_994
    assert %{0 => %InventoryItem{nameid: 537, amount: 1}} = persisted_inventory

    assert %Homunculus{hunger: 100, intimacy_hundredths: 99_994} =
             Persistence.load_for_character(character.id)

    assert [%InventoryItem{nameid: 537, amount: 1}] =
             InventoryPersistence.load_inventory(character.id)
  end

  test "feeding caps positive intimacy and hunger", %{character: character} do
    row = insert_homunculus(character.id, %{hunger: 75, intimacy_hundredths: 99_950})
    inventory = inventory_with_item(character.id, 537, 1)

    assert {:ok, fed, rearmed, %{}} =
             HungerHandler.feed(state_from(row), runtime(), inventory, timer_opts())

    assert fed.hunger == 85
    assert_receive {:timer_started, new_ref, 60_000, :hunger_tick}
    assert rearmed.hunger_timer_ref == new_ref
    assert fed.intimacy_hundredths == 100_000
  end

  test "feeding severe overfeed to zero atomically deletes row and item", %{character: character} do
    row = insert_homunculus(character.id, %{hunger: 100, intimacy_hundredths: 50})
    inventory = inventory_with_item(character.id, 537, 1)

    assert {:ok, nil, _runtime, %{}} =
             HungerHandler.feed(state_from(row), runtime(), inventory)

    assert Persistence.load_for_character(character.id) == nil
    assert InventoryPersistence.load_inventory(character.id) == []
  end

  test "missing or wrong food leaves inventory and state unchanged", %{character: character} do
    row = insert_homunculus(character.id, %{hunger: 20})
    active = state_from(row)
    wrong_inventory = inventory_with_item(character.id, 912, 2)
    runtime = runtime()

    assert {:error, :missing_food, ^active, ^runtime, ^wrong_inventory} =
             HungerHandler.feed(active, runtime, wrong_inventory)

    assert Persistence.load_for_character(character.id).hunger == 20

    assert [%InventoryItem{nameid: 912, amount: 2}] =
             InventoryPersistence.load_inventory(character.id)
  end

  test "failed feed preserves its old timer and rolls back inventory", %{character: character} do
    row = insert_homunculus(character.id, %{hunger: 20})
    active = state_from(row)
    inventory = inventory_with_item(character.id, 537, 2)
    old_ref = make_ref()
    runtime = runtime(%{hunger_timer_ref: old_ref})
    inject_repo_failure(:update)

    assert {:error, {:homunculus, %Ecto.Changeset{}}, ^active, ^runtime, ^inventory} =
             HungerHandler.feed(active, runtime, inventory, timer_opts())

    assert Persistence.load_for_character(character.id).hunger == 20
    assert [%InventoryItem{amount: 2}] = InventoryPersistence.load_inventory(character.id)
    refute_receive {:timer_cancelled, _ref}
    refute_receive {:timer_started, _ref, _delay, _event}
  end

  test "failed zero-intimacy delete rolls back food and preserves state", %{character: character} do
    row = insert_homunculus(character.id, %{hunger: 100, intimacy_hundredths: 50})
    active = state_from(row)
    inventory = inventory_with_item(character.id, 537, 1)
    runtime = runtime()
    inject_repo_failure(:delete)

    assert {:error, {:homunculus, %Ecto.Changeset{}}, ^active, ^runtime, ^inventory} =
             HungerHandler.feed(active, runtime, inventory)

    assert %Homunculus{intimacy_hundredths: 50} = Persistence.load_for_character(character.id)
    assert [%InventoryItem{amount: 1}] = InventoryPersistence.load_inventory(character.id)
  end

  test "starvation semantic failure preserves state and rearms the correct cadence", %{
    character: character
  } do
    row = insert_homunculus(character.id, %{hunger: 11})
    active = state_from(row)
    ref = make_ref()
    runtime = runtime(%{hunger_timer_ref: ref})

    stub(Persistence, :save_semantic, fn persisted, _attrs ->
      {:error, persisted |> Ecto.Changeset.change() |> Ecto.Changeset.add_error(:base, "failure")}
    end)

    assert {:error, {:homunculus, %Ecto.Changeset{}}, ^active, rearmed, %{}} =
             HungerHandler.tick(active, runtime, %{}, ref, timer_opts())

    assert Persistence.load_for_character(character.id).hunger == 11
    assert_receive {:timer_started, new_ref, 60_000, :hunger_tick}
    assert rearmed.hunger_timer_ref == new_ref
  end

  test "starvation delete failure preserves state and rearms", %{character: character} do
    row = insert_homunculus(character.id, %{hunger: 0, intimacy_hundredths: 100})
    active = state_from(row)
    ref = make_ref()
    runtime = runtime(%{hunger_timer_ref: ref})
    inject_repo_failure(:delete)

    assert {:error, {:homunculus, %Ecto.Changeset{}}, ^active, rearmed, %{}} =
             HungerHandler.tick(active, runtime, %{}, ref, timer_opts())

    assert %Homunculus{hunger: 0, intimacy_hundredths: 100} =
             Persistence.load_for_character(character.id)

    assert_receive {:timer_started, new_ref, 20_000, :hunger_tick}
    assert rearmed.hunger_timer_ref == new_ref
  end

  test "missing-food auto-feed falls through to the current starvation tick", %{
    character: character
  } do
    row = insert_homunculus(character.id, %{hunger: 0, intimacy_hundredths: 200})
    config = %{Config.default() | auto_feed: true, auto_feed_threshold: 10}
    active = %{state_from(row) | ai_config: config}
    ref = make_ref()
    runtime = runtime(%{hunger_timer_ref: ref})

    assert {:noop, ^active, ^runtime, %{}} =
             HungerHandler.auto_feed(active, runtime, %{}, timer_opts())

    refute_receive {:timer_cancelled, _ref}
    refute_receive {:timer_started, _ref, _delay, _event}

    assert {:ok, starved, rearmed, %{}} =
             HungerHandler.tick(active, runtime, %{}, ref, timer_opts())

    assert starved.hunger == 0
    assert starved.intimacy_hundredths == 100
    assert_receive {:timer_started, new_ref, 20_000, :hunger_tick}
    assert rearmed.hunger_timer_ref == new_ref
  end

  test "auto-feed triggers only when enabled and due; missing food falls through", %{
    character: character
  } do
    row = insert_homunculus(character.id, %{hunger: 10})
    config = %{Config.default() | auto_feed: true, auto_feed_threshold: 10}
    active = %{state_from(row) | ai_config: config}
    runtime = runtime()

    assert {:noop, ^active, ^runtime, %{}} =
             HungerHandler.auto_feed(active, runtime, %{})

    not_due = %{active | hunger: 11}
    assert {:noop, ^not_due, ^runtime, %{}} = HungerHandler.auto_feed(not_due, runtime, %{})

    disabled = %{active | ai_config: %{config | auto_feed: false}}
    assert {:noop, ^disabled, ^runtime, %{}} = HungerHandler.auto_feed(disabled, runtime, %{})

    inventory = inventory_with_item(character.id, 537, 1)

    assert {:ok, fed, rearmed, %{}} =
             HungerHandler.auto_feed(active, runtime, inventory, timer_opts())

    assert fed.hunger == 20
    assert_receive {:timer_started, new_ref, 60_000, :hunger_tick}
    assert rearmed.hunger_timer_ref == new_ref
  end

  defp timer_opts(extra \\ []) do
    test_pid = self()

    defaults = [
      timer_start: fn delay, event ->
        ref = make_ref()
        send(test_pid, {:timer_started, ref, delay, event})
        ref
      end,
      timer_cancel: fn ref -> send(test_pid, {:timer_cancelled, ref}) end,
      timer_read: fn _ref -> false end
    ]

    Keyword.merge(defaults, extra)
  end

  defp runtime(attrs \\ %{}) do
    struct!(Runtime, Map.merge(%{private_dirty: false, clocks_online: true}, attrs))
  end

  defp state(attrs) do
    struct!(
      HomunculusState,
      Map.merge(
        %{
          id: 1,
          owner_character_id: 1,
          class_id: 6_001,
          name: "Lif",
          lifecycle: :active,
          hp: 100,
          max_hp: 100,
          hunger: 32,
          intimacy_hundredths: 2_100
        },
        attrs
      )
    )
  end

  defp state_from(row) do
    state(%{
      id: row.id,
      owner_character_id: row.character_id,
      class_id: row.class_id,
      hunger: row.hunger,
      intimacy_hundredths: row.intimacy_hundredths
    })
  end

  defp inventory_with_item(character_id, nameid, amount) do
    {:ok, item} =
      InventoryPersistence.insert_item(character_id, %{
        nameid: nameid,
        amount: amount,
        identify: 1
      })

    PlayerState.from_list([item])
  end

  defp inject_repo_failure(operation) do
    stub(Repo, operation, fn
      %Ecto.Changeset{data: %Homunculus{}} = changeset, _opts ->
        {:error, Ecto.Changeset.add_error(changeset, :base, "injected failure")}

      changeset, opts ->
        Mimic.call_original(Repo, operation, [changeset, opts])
    end)
  end

  defp insert_homunculus(character_id, attrs) do
    defaults = %{
      character_id: character_id,
      class_id: 6_001,
      name: "Lif",
      hp: 100,
      max_hp: 100,
      sp: 50,
      max_sp: 50
    }

    {:ok, homunculus} =
      %Homunculus{}
      |> Homunculus.changeset(Map.merge(defaults, attrs))
      |> Repo.insert()

    homunculus
  end
end
