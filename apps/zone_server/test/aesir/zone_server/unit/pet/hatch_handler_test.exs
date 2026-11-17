defmodule Aesir.ZoneServer.Unit.Pet.HatchHandlerTest do
  use Aesir.DataCase, async: true

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.Models.Pet
  alias Aesir.Net.ChatNotice
  alias Aesir.Net.PetEggList
  alias Aesir.Net.PetPrivateState
  alias Aesir.Net.PetStateChange
  alias Aesir.Net.SkillMenuReply
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.PetManagement.Catalog
  alias Aesir.ZoneServer.Mmo.PetManagement.Egg
  alias Aesir.ZoneServer.Unit.Pet.Handlers.HatchHandler
  alias Aesir.ZoneServer.Unit.Pet.Persistence
  alias Aesir.ZoneServer.Unit.Pet.PetState
  alias Aesir.ZoneServer.Unit.Pet.Runtime
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillMenuHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.SkillRequest
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "pet_hatch_map"
  @potion 501

  setup :setup_ets_tables
  setup :set_mimic_private

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 60, 60)})

    suffix = System.unique_integer([:positive])
    username = "phh#{suffix}"

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
          name: "Phh#{suffix}",
          class: 1,
          base_level: 1,
          str: 1,
          agi: 1,
          vit: 1,
          int: 1,
          dex: 1,
          luk: 1
        })
      )

    {:ok, definition} = Catalog.by_mob(1002)

    {:ok, inventory, pet} =
      Persistence.create_with_egg(
        account.id,
        character.id,
        definition,
        %{level: 1, name: "Poring"},
        %{},
        :infinity
      )

    {:ok, egg} = Egg.find(inventory, pet.id)
    {egg_index, _egg} = Enum.find(inventory, fn {_index, item} -> item.id == egg.id end)

    %{
      character: character,
      definition: definition,
      inventory: inventory,
      pet: pet,
      egg_index: egg_index
    }
  end

  describe "open_egg_list/1" do
    test "lists every egg and parks the offer", ctx do
      inventory = Map.put(ctx.inventory, 90, %InventoryItem{nameid: @potion, amount: 1})

      opened = HatchHandler.open_egg_list(session(ctx.character, inventory))

      assert SkillMenuHandler.pet_egg_offer?(opened)
      egg_index = ctx.egg_index + 2
      assert_receive {:send, _, {:pet_egg_list, %PetEggList{indexes: [^egg_index]}}}
    end

    test "with a pet out sends nothing", ctx do
      session = %{session(ctx.character, ctx.inventory) | pet: pet_out(ctx)}

      assert HatchHandler.open_egg_list(session) == session
      refute_received {:send, _, _}
    end

    test "on a GvG map with pet_disable_in_gvg sends message 666 and no list", ctx do
      stub(Config, :pet_disable_in_gvg?, fn -> true end)
      stub(MapFlags, :gvg2?, fn @map -> true end)
      session = session(ctx.character, ctx.inventory)

      assert HatchHandler.open_egg_list(session) == session

      assert_receive {:send, _,
                      {:chat_notice,
                       %ChatNotice{kind: :INFO, text: "Pets are not allowed in Guild Wars."}}}

      refute_received {:send, _, {:pet_egg_list, _}}
    end
  end

  describe "select_egg/2" do
    test "stale or forged egg selection is ignored", ctx do
      plain_egg = %InventoryItem{nameid: ctx.definition.egg_item_id, amount: 1, card0: 0}

      inventory =
        ctx.inventory
        |> Map.put(90, %InventoryItem{nameid: @potion, amount: 1})
        |> Map.put(91, plain_egg)

      session = session(ctx.character, inventory)

      assert HatchHandler.select_egg(session, ctx.egg_index) == session

      offered = SkillMenuHandler.open_pet_egg_offer(session)

      for index <- [999, 90, 91] do
        selected = HatchHandler.select_egg(offered, index)

        assert selected.pet == nil
        assert selected.pending_skill_menu == nil
      end

      assert %Pet{incubate: 1} = Repo.get!(Pet, ctx.pet.id)
    end

    test "hatches the egg next to its owner", ctx do
      session = ctx.character |> session(ctx.inventory) |> SkillMenuHandler.open_pet_egg_offer()

      hatched = HatchHandler.select_egg(session, ctx.egg_index)

      assert %PetState{pet_id: pet_id, world_gid: gid, name: "Poring"} = hatched.pet
      assert pet_id == ctx.pet.id
      assert hatched.pending_skill_menu == nil
      assert is_reference(hatched.pet_runtime.ai_timer_ref)

      assert {:ok, {PetState, %PetState{world_gid: ^gid}, _pid}} =
               UnitRegistry.get_unit(:pet, gid)

      assert %{attribute: 1, id: egg_id} = hatched.game_state.inventory[ctx.egg_index]
      assert Repo.get!(InventoryItem, egg_id).attribute == 1

      character_id = ctx.character.id
      account_id = ctx.character.account_id

      assert %Pet{incubate: 0, char_id: ^character_id, account_id: ^account_id} =
               Repo.get!(Pet, pet_id)

      assert Repo.get!(Character, character_id).pet_id == pet_id

      assert_receive {:send, _,
                      {:pet_state_change, %PetStateChange{gid: ^gid, type: :PET_STATE_INIT}}}

      assert_receive {:send, _,
                      {:pet_state_change,
                       %PetStateChange{gid: ^gid, type: :PET_STATE_UPDATE_EGG, value: 1}}}

      assert_receive {:send, _,
                      {:pet_state_change,
                       %PetStateChange{gid: ^gid, type: :PET_STATE_ACCESSORY, value: 0}}}

      assert_receive {:send, _, {:pet_private_state, %PetPrivateState{gid: ^gid}}}
    end

    test "while trading only closes the list", ctx do
      session =
        %{session(ctx.character, ctx.inventory) | trade: :open}
        |> SkillMenuHandler.open_pet_egg_offer()

      selected = HatchHandler.select_egg(session, ctx.egg_index)

      assert selected.pet == nil
      assert selected.pending_skill_menu == nil
    end
  end

  describe "the parked egg list" do
    test "a skill request closes it", ctx do
      Mimic.copy(SkillRequest)

      stub(SkillRequest, :targeted, fn _state, _skill_id, _level, _target, _now ->
        {:use,
         %{
           origin: :skill,
           level: 0,
           target: ctx.character.id,
           ends_invincibility?: false,
           clears_item_skill?: false
         }}
      end)

      session = ctx.character |> session(ctx.inventory) |> SkillMenuHandler.open_pet_egg_offer()

      assert {:noreply, %SessionState{pending_skill_menu: nil}} =
               SkillHandler.handle_use_skill(session, 28, 1, ctx.character.id)
    end

    test "a skill menu reply never answers it", ctx do
      session = ctx.character |> session(ctx.inventory) |> SkillMenuHandler.open_pet_egg_offer()
      reply = %SkillMenuReply{src_skill_id: 297, selected_id: ctx.egg_index}

      assert {:noreply, ^session} = SkillMenuHandler.handle_reply(reply, session)
    end
  end

  defp pet_out(ctx) do
    %PetState{
      pet_id: ctx.pet.id,
      owner_char_id: ctx.character.id,
      owner_account_id: ctx.character.account_id,
      class_id: 1002,
      name: "Poring",
      level: 1,
      egg_id: ctx.definition.egg_item_id,
      intimate: 250,
      hungry: 100
    }
  end

  defp session(character, inventory) do
    %SessionState{
      game_state: %PlayerState{
        character_id: character.id,
        account_id: character.account_id,
        character_name: character.name,
        map_name: @map,
        x: 10,
        y: 10,
        dir: 0,
        walk_speed: 150,
        movement_state: :standing,
        view_range: 14,
        inventory: inventory
      },
      connection_pid: self(),
      pet_runtime: %Runtime{generation: 3}
    }
  end
end
