defmodule Aesir.ZoneServer.Unit.Pet.OwnerBonusTest do
  use Aesir.DataCase, async: true

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.Models.Pet
  alias Aesir.Net.SkillList
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat.EquipAutobonus
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipLocation
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions
  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions.Option
  alias Aesir.ZoneServer.Mmo.PetManagement.Catalog
  alias Aesir.ZoneServer.Mmo.PetManagement.Egg
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Pet.Handlers.HatchHandler
  alias Aesir.ZoneServer.Unit.Pet.Handlers.HungerHandler
  alias Aesir.ZoneServer.Unit.Pet.Handlers.LifecycleHandler
  alias Aesir.ZoneServer.Unit.Pet.Persistence
  alias Aesir.ZoneServer.Unit.Pet.Runtime
  alias Aesir.ZoneServer.Unit.Player.Handlers.EquipProcHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillMenuHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.EquipmentFold
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "pet_bonus_map"
  @worn_item 999_981
  @temporary_card 999_982
  @option 9_981

  setup :setup_ets_tables
  setup :set_mimic_private

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 60, 60)})

    suffix = System.unique_integer([:positive])
    username = "pob#{suffix}"

    account =
      Repo.insert!(
        Account.changeset(%Account{}, %{
          username: username,
          userid: username,
          user_pass: "password",
          email: "#{username}@example.com"
        })
      )

    character =
      Repo.insert!(
        Character.changeset(%Character{}, %{
          account_id: account.id,
          char_num: 0,
          name: "Pob#{suffix}",
          class: 0,
          base_level: 1,
          job_level: 1,
          str: 1,
          agi: 1,
          vit: 1,
          int: 1,
          dex: 1,
          luk: 1
        })
      )

    %{character: character}
  end

  describe "the equipment fold" do
    test "runs the pet program after the options and the temporary card", ctx do
      stub(RandomOptions, :option, fn
        @option ->
          {:ok,
           %Option{
             id: @option,
             name: "PET_ORDER",
             program:
               EquipScript.parse!("""
               grant_skill(ctx, 28, 1)
               set(ctx, :atk_ele, :water)
               """)
           }}
      end)

      stub(Items, :by_id, fn
        @worn_item ->
          {:ok,
           %ItemDefinition{
             id: @worn_item,
             aegis_name: "Pet_Bonus_Test",
             name: "Pet bonus test",
             type: :armor,
             on_equip: EquipScript.parse!("bonus(ctx, :luk, 1)")
           }}

        @temporary_card ->
          {:ok,
           %ItemDefinition{
             id: @temporary_card,
             aegis_name: "Pet_Order_Card",
             name: "Pet order card",
             type: :card,
             on_equip:
               EquipScript.parse!("""
               grant_skill(ctx, 29, 1)
               set(ctx, :atk_ele, :fire)
               """)
           }}

        id ->
          call_original(Items, :by_id, [id])
      end)

      program =
        EquipScript.parse!("""
        ctx = bonus(ctx, :luk, 3)
        ctx = set(ctx, :atk_ele, :wind)
        if (skill_lv(ctx, 28) > 0 && skill_lv(ctx, 29) > 0) do
          ctx = bonus(ctx, :str, 5)
          ctx
        else
          ctx
        end
        if (pet_info(ctx, :intimate) >= 910) do
          ctx = bonus(ctx, :critical, 1)
          ctx
        else
          ctx
        end
        """)

      worn = [
        %InventoryItem{
          id: 1,
          nameid: @worn_item,
          equip: EquipLocation.location_bit(:armor),
          random_options: [%{id: @option, value: 0, param: 0}]
        }
      ]

      stats = PlayerState.new(ctx.character).stats
      pet_bonus = %{program: program, inputs: %{pet: %{intimate: 910}}, skill_bonus: nil}

      folded =
        EquipmentFold.apply_equipment_modifiers(%{stats | pet_bonus: pet_bonus}, worn, %{
          temporary_card_id: @temporary_card
        })

      assert Stats.get_equipment_modifier(folded, :luk) == 4
      assert Stats.get_equipment_modifier(folded, :str) == 5
      assert Stats.get_equipment_modifier(folded, :critical) == 1
      assert folded.modifiers.equipment[:atk_ele] == :wind

      no_script = %{pet_bonus | program: []}

      assert EquipmentFold.apply_equipment_modifiers(%{stats | pet_bonus: no_script}, worn).modifiers ==
               EquipmentFold.apply_equipment_modifiers(stats, worn).modifiers
    end
  end

  describe "the owner recompute" do
    @tag game_mode: :renewal
    test "hatching, raising intimacy and returning a Cordial Poring", ctx do
      {inventory, egg_index, pet_id} = pet_egg(ctx.character, 1002, %{intimate: 750})
      base = session(ctx.character, inventory)
      base_luk = Stats.get_effective_stat(base.game_state.stats, :luk)
      base_crit = base.game_state.stats.combat_stats.critical

      hatched = hatch(base, egg_index)

      assert hatched.pet.pet_id == pet_id
      assert Stats.get_effective_stat(hatched.game_state.stats, :luk) == base_luk + 2
      assert Stats.get_equipment_modifier(hatched.game_state.stats, :critical) == 1
      assert hatched.game_state.stats.combat_stats.critical > base_crit
      assert hatched.game_state.stats.generation > base.game_state.stats.generation

      loyal = HungerHandler.set_intimate(hatched, 910)

      assert Stats.get_effective_stat(loyal.game_state.stats, :luk) == base_luk + 3

      returned = LifecycleHandler.return_to_egg(loyal)

      assert returned.pet == nil
      assert returned.game_state.stats.pet_bonus == nil
      assert Stats.get_effective_stat(returned.game_state.stats, :luk) == base_luk
      assert returned.game_state.stats.combat_stats.critical == base_crit
    end

    @tag game_mode: :renewal
    test "setting an unchanged intimacy recomputes the owner", ctx do
      {inventory, egg_index, _pet_id} = pet_egg(ctx.character, 1002, %{intimate: 910})
      hatched = ctx.character |> session(inventory) |> hatch(egg_index)

      same = HungerHandler.set_intimate(hatched, 910)

      assert same.pet.intimate == 910
      assert same.game_state.stats.generation == hatched.game_state.stats.generation + 1
    end

    test "feeding recomputes the owner before the hunger rise", ctx do
      {:ok, poring} = Catalog.by_mob(1002)

      program =
        EquipScript.parse!("""
        if (pet_info(ctx, :hungry) <= 50) do
          ctx = bonus(ctx, :luk, 7)
          ctx
        else
          ctx
        end
        """)

      stub(Catalog, :by_mob, fn 1002 ->
        {:ok, %{poring | bonus_program: program, food_item_id: 0, hunger_increase: 20}}
      end)

      {inventory, egg_index, _pet_id} =
        pet_egg(ctx.character, 1002, %{intimate: 500, hungry: 40})

      base = session(ctx.character, inventory)
      base_luk = Stats.get_effective_stat(base.game_state.stats, :luk)
      hatched = hatch(base, egg_index)

      fed = HungerHandler.feed(hatched)

      assert fed.pet.hungry == 60
      assert fed.game_state.stats.pet_bonus.inputs.pet.hungry == 60
      assert fed.game_state.stats.generation == hatched.game_state.stats.generation + 1
      assert Stats.get_effective_stat(fed.game_state.stats, :luk) == base_luk + 7
    end

    @tag game_mode: :renewal
    test "hatching and returning a Whisper publishes the Hiding grant", ctx do
      {inventory, egg_index, _pet_id} = pet_egg(ctx.character, 1179, %{intimate: 250})

      hatched = ctx.character |> session(inventory) |> hatch(egg_index)

      assert_received {:send, _, {_, %SkillList{skills: skills}}}
      assert Enum.any?(skills, &(&1.skill_id == 51))

      LifecycleHandler.return_to_egg(hatched)

      assert_received {:send, _, {_, %SkillList{skills: skills}}}
      refute Enum.any?(skills, &(&1.skill_id == 51))
    end

    test "a status the pet program starts follows the pet", ctx do
      {:ok, poring} = Catalog.by_mob(1002)
      program = EquipScript.parse!("status_start(ctx, :sc_summer, :infinite, 3)")

      stub(Catalog, :by_mob, fn 1002 -> {:ok, %{poring | bonus_program: program}} end)

      {inventory, egg_index, _pet_id} = pet_egg(ctx.character, 1002, %{intimate: 500})
      hatched = ctx.character |> session(inventory) |> hatch(egg_index)

      assert %{val1: 3} = StatusStorage.get_status(:player, ctx.character.id, :sc_summer)

      LifecycleHandler.return_to_egg(hatched)

      refute StatusStorage.has_status?(:player, ctx.character.id, :sc_summer)
    end

    test "a pet with no script leaves the owner's stats unchanged", ctx do
      {inventory, egg_index, _pet_id} = pet_egg(ctx.character, 1122, %{intimate: 1000})
      base = session(ctx.character, inventory)

      hatched = hatch(base, egg_index)

      assert hatched.pet.class_id == 1122
      assert hatched.game_state.stats.modifiers == base.game_state.stats.modifiers
      assert hatched.game_state.stats.generation == base.game_state.stats.generation
    end
  end

  describe "pet autobonuses" do
    @marionette """
    pet_autobonus(ctx, %{other: nil, bonus: [{:bonus, {:subele, :neutral}, 2}, {:heal, 100, 0}], trigger: :attack, battle_flag: 529}, 100, 5000)
    """

    test "trigger on a short normal attack, apply for the duration, then expire", ctx do
      hatched = hatch_with_program(ctx, @marionette)
      registrations = hatched.game_state.stats.equip_autobonuses
      test_pid = self()

      roll = fn rate ->
        send(test_pid, {:rolled, rate})
        true
      end

      assert [{:pet, _} = key] = EquipAutobonus.on_attack(registrations, 529, roll: roll)
      assert_received {:rolled, 100}
      assert EquipAutobonus.on_attack(registrations, 2 + 512 + 16, roll: roll) == []

      before = System.monotonic_time(:millisecond)
      {:noreply, active} = EquipProcHandler.activate(hatched, key, {:pet, 1002})
      after_activation = System.monotonic_time(:millisecond)
      timer = Map.fetch!(active.pet_runtime.autobonus_timers, key)
      read_before = System.monotonic_time(:millisecond)
      remaining = Process.read_timer(timer)
      read_after = System.monotonic_time(:millisecond)

      assert Stats.get_equipment_modifier(active.game_state.stats, {:subele, :neutral}) == 2
      assert read_before + remaining <= after_activation + 5_001
      assert read_after + remaining >= before + 4_999

      generation = Map.fetch!(active.game_state.stats.active_autobonuses, key)
      {:noreply, expired} = EquipProcHandler.expire(active, key, generation)
      assert Stats.get_equipment_modifier(expired.game_state.stats, {:subele, :neutral}) == 0
      assert Map.has_key?(expired.game_state.stats.equip_autobonuses, key)
      assert expired.pet_runtime.autobonus_timers == %{}
    end

    test "the same script registered twice in one pet program registers once", ctx do
      hatched = hatch_with_program(ctx, @marionette <> @marionette)

      assert [{:pet, 0}] = Map.keys(hatched.game_state.stats.equip_autobonuses)
    end

    test "returning the pet to its egg drops an active autobonus at once", ctx do
      hatched = hatch_with_program(ctx, @marionette)
      [key] = Map.keys(hatched.game_state.stats.equip_autobonuses)
      {:noreply, active} = EquipProcHandler.activate(hatched, key, {:pet, 1002})
      timer = Map.fetch!(active.pet_runtime.autobonus_timers, key)
      active = put_in(active.game_state.stats.current_state.hp, 1)

      returned = LifecycleHandler.return_to_egg(active)

      assert returned.game_state.stats.equip_autobonuses == %{}
      assert returned.game_state.stats.active_autobonuses == %{}
      assert Stats.get_equipment_modifier(returned.game_state.stats, {:subele, :neutral}) == 0
      assert returned.game_state.stats.current_state.hp == 1
      assert Process.read_timer(timer) == false
    end
  end

  defp hatch_with_program(ctx, source) do
    {:ok, poring} = Catalog.by_mob(1002)
    program = EquipScript.parse!(source)
    stub(Catalog, :by_mob, fn 1002 -> {:ok, %{poring | bonus_program: program}} end)
    stub(CharacterPersistence, :update_stats, fn _character_id, _attrs, _opts -> {:ok, nil} end)
    {inventory, egg_index, _pet_id} = pet_egg(ctx.character, 1002, %{intimate: 500})
    ctx.character |> session(inventory) |> hatch(egg_index)
  end

  defp hatch(session, egg_index) do
    session
    |> SkillMenuHandler.open_pet_egg_offer()
    |> HatchHandler.select_egg(egg_index)
  end

  defp pet_egg(character, mob_id, attrs) do
    {:ok, definition} = Catalog.by_mob(mob_id)

    {:ok, inventory, pet} =
      Persistence.create_with_egg(
        character.account_id,
        character.id,
        definition,
        %{level: 1, name: "Pet"},
        %{},
        :infinity
      )

    pet |> Pet.changeset(attrs) |> Repo.update!()
    {:ok, egg} = Egg.find(inventory, pet.id)
    {egg_index, _egg} = Enum.find(inventory, fn {_index, item} -> item.id == egg.id end)
    {inventory, egg_index, pet.id}
  end

  defp session(character, inventory) do
    game_state = %{
      PlayerState.new(character)
      | map_name: @map,
        x: 10,
        y: 10,
        inventory: inventory
    }

    :ok = UnitRegistry.register_player(game_state, self())

    %SessionState{
      game_state: game_state,
      connection_pid: self(),
      pet_runtime: %Runtime{generation: 1}
    }
  end
end
