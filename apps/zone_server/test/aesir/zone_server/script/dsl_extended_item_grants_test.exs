defmodule Aesir.ZoneServer.Script.DslExtendedItemGrantsTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private

  @sword 1101
  @potion 501
  @egg 9001

  defmodule StubSession do
    use GenServer

    def start_link(test), do: GenServer.start_link(__MODULE__, test)

    @impl true
    def init(test), do: {:ok, test}

    @impl true
    def handle_call({:npc, {:script_apply, op}}, _from, test) do
      send(test, {:script_apply, self(), op})
      {:reply, {:ok, %PlayerState{character_id: 1}}, test}
    end
  end

  setup do
    defs = %{
      @sword => %ItemDefinition{id: @sword, aegis_name: "Sword", name: "Sword", type: :weapon},
      @potion => %ItemDefinition{id: @potion, aegis_name: "Red_Potion", name: "P", type: :healing},
      @egg => %ItemDefinition{id: @egg, aegis_name: "Egg", name: "Egg", type: :pet_egg}
    }

    stub(Items, :by_id, &Map.fetch(defs, &1))
    {:ok, session} = StubSession.start_link(self())
    %{session: session}
  end

  defp ctx(session) do
    %Ctx{
      char_id: 1,
      account_id: 100,
      connection_pid: self(),
      session_pid: session,
      game_state: %PlayerState{character_id: 1},
      source: {:npc, :test}
    }
  end

  defp max_refine, do: if(GameMode.mode() == :renewal, do: 20, else: 10)

  describe "getitem2" do
    test "gear keeps identify and attribute and caps the refine", %{session: s} do
      Dsl.getitem2(ctx(s), @sword, 1, 0, 99, 1, 4001, 0, 0, 0)

      assert_received {:script_apply, ^s, {:give_item2, @sword, 1, attrs}}
      assert %{identify: 0, refine: refine, attribute: 1, card0: 4001} = attrs
      assert refine == max_refine()
    end

    test "a pet egg is identified and unrefined but keeps its attribute", %{session: s} do
      Dsl.getitem2(ctx(s), @egg, 1, 0, 5, 1, 0, 0, 0, 0)

      assert_received {:script_apply, ^s,
                       {:give_item2, @egg, 1, %{identify: 1, refine: 0, attribute: 1}}}
    end

    test "any other item is identified, unrefined and without attribute", %{session: s} do
      Dsl.getitem2(ctx(s), @potion, 3, 0, 5, 1, 0, 0, 0, 0)

      assert_received {:script_apply, ^s,
                       {:give_item2, @potion, 3, %{identify: 1, refine: 0, attribute: 0}}}
    end

    test "grants to the online player of an account id, and does nothing for an offline one", %{
      session: s
    } do
      {:ok, target} = StubSession.start_link(self())

      stub(UnitRegistry, :get_char_id_by_account, fn
        200 -> {:ok, 2}
        _other -> {:error, :not_found}
      end)

      stub(UnitRegistry, :get_unit, fn :player, 2 ->
        {:ok, {PlayerState, %PlayerState{}, target}}
      end)

      assert %Ctx{status: :ok} = Dsl.getitem2(ctx(s), @sword, 1, 1, 0, 0, 0, 0, 0, 0, 200)
      assert_received {:script_apply, ^target, {:give_item2, @sword, 1, _attrs}}

      assert %Ctx{status: :ok} = Dsl.getitem2(ctx(s), @sword, 1, 1, 0, 0, 0, 0, 0, 0, 300)
      refute_received {:script_apply, _pid, _op}
    end

    test "an unknown item stops the script", %{session: s} do
      assert %Ctx{status: {:error, :unknown_item}} =
               Dsl.getitem2(ctx(s), 1, 1, 1, 0, 0, 0, 0, 0, 0)
    end
  end

  describe "the option and bound variants" do
    test "getitem3 adds the random options", %{session: s} do
      options = [%{id: 3, value: 5, param: 0}]
      Dsl.getitem3(ctx(s), @sword, 1, 1, 0, 0, 0, 0, 0, 0, options)

      assert_received {:script_apply, ^s, {:give_item2, @sword, 1, %{random_options: ^options}}}
    end

    test "getitembound2/3 bind the item and refuse a binding outside 0..4", %{session: s} do
      Dsl.getitembound2(ctx(s), @sword, 1, 1, 0, 0, 0, 0, 0, 0, 4)
      assert_received {:script_apply, ^s, {:give_item2, @sword, 1, %{bound: 4}}}

      Dsl.getitembound3(ctx(s), @sword, 1, 1, 0, 0, 0, 0, 0, 0, 2, [%{id: 3, value: 1, param: 0}])

      assert_received {:script_apply, ^s,
                       {:give_item2, @sword, 1, %{bound: 2, random_options: [_]}}}

      assert %Ctx{status: {:error, :bad_bound}} =
               Dsl.getitembound2(ctx(s), @sword, 1, 1, 0, 0, 0, 0, 0, 0, 5)
    end
  end

  describe "rentitem2/3" do
    test "grant one unit expiring after the seconds, any item type, with the attributes", %{
      session: s
    } do
      Dsl.rentitem2(ctx(s), @potion, 0, 0, 5, 1, 0, 0, 0, 0)

      assert_received {:script_apply, ^s,
                       {:give_item2, @potion, 1,
                        %{expire_seconds: 0, identify: 1, refine: 0, attribute: 0}}}

      Dsl.rentitem3(ctx(s), @sword, 60, 0, 4, 1, 0, 0, 0, 0, [%{id: 3, value: 1, param: 0}])

      assert_received {:script_apply, ^s,
                       {:give_item2, @sword, 1,
                        %{expire_seconds: 60, identify: 0, refine: 4, random_options: [_]}}}
    end

    test "plain rentitem rents to an account id's player and stops for an offline one", %{
      session: s
    } do
      {:ok, target} = StubSession.start_link(self())

      stub(UnitRegistry, :get_char_id_by_account, fn
        200 -> {:ok, 2}
        _other -> {:error, :not_found}
      end)

      stub(UnitRegistry, :get_unit, fn :player, 2 ->
        {:ok, {PlayerState, %PlayerState{}, target}}
      end)

      assert %Ctx{status: :ok} = Dsl.give_item_rental(ctx(s), @potion, 30, 200)
      assert_received {:script_apply, ^target, {:give_item2, @potion, 1, %{expire_seconds: 30}}}

      assert %Ctx{status: {:error, :no_player}} = Dsl.give_item_rental(ctx(s), @potion, 30, 300)
    end

    test "an offline getitem target is skipped before the item is looked up", %{session: s} do
      stub(UnitRegistry, :get_char_id_by_account, fn _ -> {:error, :not_found} end)

      assert %Ctx{status: :ok} = Dsl.getitem2(ctx(s), 1, 1, 1, 0, 0, 0, 0, 0, 0, 300)
    end

    test "an offline target stops the script", %{session: s} do
      stub(UnitRegistry, :get_char_id_by_account, fn _ -> {:error, :not_found} end)

      assert %Ctx{status: {:error, :no_player}} =
               Dsl.rentitem2(ctx(s), @sword, 60, 1, 0, 0, 0, 0, 0, 0, 300)
    end
  end
end
