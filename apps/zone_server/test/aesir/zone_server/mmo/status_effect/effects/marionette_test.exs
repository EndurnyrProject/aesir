defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MarionetteTest do
  use ExUnit.Case, async: true
  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skills.Clown.Formulas
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Marionette
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Marionette2
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  @gid 90_001

  setup do
    for {id, x} <- [{17, 100}, {18, 107}] do
      player =
        PlayerState.new(%Character{
          id: id,
          account_id: id,
          name: "Marionette #{id}",
          class: 4020,
          base_level: 80,
          job_level: 50,
          sex: "M",
          last_map: "prontera",
          last_x: x,
          last_y: 100,
          str: 80,
          agi: 10,
          vit: 0,
          int: 10,
          dex: 10,
          luk: 0
        })

      :ok = UnitRegistry.register_player(player, self())
      :ok = SpatialIndex.add_player(id, x, 100, "prontera")
    end

    %{link: make_ref()}
  end

  test "ticks retain a matching living peer at seven cells and remove at eight or on a different map",
       %{link: link} do
    pair(link)
    entry = StatusStorage.get_status(:player, 17, :sc_marionette)
    assert {:ok, ^entry} = Marionette.on_tick({:player, 17}, entry, %{})
    :ok = SpatialIndex.update_unit_position(:player, 18, 108, 100, "prontera")
    assert :remove = Marionette.on_tick({:player, 17}, entry, %{})
    :ok = SpatialIndex.remove_unit(:player, 18)
    :ok = SpatialIndex.add_player(18, 107, 100, "geffen")
    assert :remove = Marionette.on_tick({:player, 17}, entry, %{})
  end

  test "ticks remove a missing, differently linked or dead peer", %{link: link} do
    pair(link)
    entry = StatusStorage.get_status(:player, 17, :sc_marionette)

    :ok =
      StatusStorage.update_status(:player, 18, :sc_marionette2, fn peer ->
        %{peer | state: Map.put(peer.state, :link_id, make_ref())}
      end)

    assert :remove = Marionette.on_tick({:player, 17}, entry, %{})
    pair(link)
    {:ok, {_, player, _}} = UnitRegistry.get_unit(:player, 18)
    :ok = UnitRegistry.update_unit_state(:player, 18, put_in(player.stats.current_state.hp, 0))
    assert :remove = Marionette.on_tick({:player, 17}, entry, %{})
    StatusStorage.remove_status(:player, 18, :sc_marionette2)
    assert :remove = Marionette.on_tick({:player, 17}, entry, %{})
  end

  test "expiry closes the puppet with its back-reference cleared so it does not echo", %{
    link: link
  } do
    pair(link)
    entry = StatusStorage.get_status(:player, 17, :sc_marionette)
    assert :ok = Marionette.on_expire({:player, 17}, entry, %{})
    refute StatusStorage.has_status?(:player, 18, :sc_marionette2)
    assert StatusStorage.has_status?(:player, 17, :sc_marionette)
    assert :ok = Marionette.on_expire({:player, 17}, entry, %{})
  end

  test "normal removal of either half ends the matching pair", %{link: link} do
    for {id, status} <- [{17, :sc_marionette}, {18, :sc_marionette2}] do
      pair(link)
      assert :ok = Interpreter.remove_status(:player, id, status)
      refute StatusStorage.has_status?(:player, 17, :sc_marionette)
      refute StatusStorage.has_status?(:player, 18, :sc_marionette2)
    end
  end

  test "an old expiry does not close a peer's newer link", %{link: link} do
    pair(link)
    entry = StatusStorage.get_status(:player, 17, :sc_marionette)

    :ok =
      StatusStorage.update_status(:player, 18, :sc_marionette2, fn peer ->
        %{peer | state: Map.put(peer.state, :link_id, make_ref())}
      end)

    assert :ok = Marionette.on_expire({:player, 17}, entry, %{})
    assert StatusStorage.has_status?(:player, 18, :sc_marionette2)
  end

  test "frozen modifiers halve the master's STR and cap the puppet at ninety-nine", %{link: link} do
    pair(link)
    master = StatusStorage.get_status(:player, 17, :sc_marionette)
    puppet = StatusStorage.get_status(:player, 18, :sc_marionette2)
    assert %{str: -40, max_hp: -1000} = Marionette.modifiers(master, %{})
    assert %{str: 39} = Marionette2.modifiers(puppet, %{})
    assert master.expires_at == nil
    assert puppet.expires_at == nil
  end

  test "ticks keep a Homunculus puppet within seven cells on the same map", %{link: link} do
    pair_with_homunculus(link)
    entry = StatusStorage.get_status(:player, 17, :sc_marionette)
    assert {:ok, ^entry} = Marionette.on_tick({:player, 17}, entry, %{})
    puppet = StatusStorage.get_status(:homunculus, @gid, :sc_marionette2)
    assert {:ok, ^puppet} = Marionette2.on_tick({:homunculus, @gid}, puppet, %{})

    :ok = SpatialIndex.update_unit_position(:homunculus, @gid, 108, 100, "prontera")
    assert :remove = Marionette.on_tick({:player, 17}, entry, %{})

    :ok = SpatialIndex.update_unit_position(:homunculus, @gid, 100, 100, "geffen")
    assert :remove = Marionette.on_tick({:player, 17}, entry, %{})
  end

  test "the Homunculus half's expiry closes the master half", %{link: link} do
    pair_with_homunculus(link)
    entry = StatusStorage.get_status(:homunculus, @gid, :sc_marionette2)
    assert :ok = Marionette2.on_expire({:homunculus, @gid}, entry, %{})
    refute StatusStorage.has_status?(:player, 17, :sc_marionette)
    assert StatusStorage.has_status?(:homunculus, @gid, :sc_marionette2)
  end

  test "death ends both halves immediately", %{link: link} do
    pair_with_homunculus(link)
    assert :ok = Interpreter.remove_on_death(:homunculus, @gid)
    refute StatusStorage.has_status?(:player, 17, :sc_marionette)
    refute StatusStorage.has_status?(:homunculus, @gid, :sc_marionette2)

    pair_with_homunculus(make_ref())
    assert :ok = Interpreter.remove_on_death(:player, 17)
    refute StatusStorage.has_status?(:player, 17, :sc_marionette)
    refute StatusStorage.has_status?(:homunculus, @gid, :sc_marionette2)
  end

  test "the Homunculus puppet's gains reach its stat aggregation", %{link: link} do
    pair_with_homunculus(link)

    modifiers = ModifierCalculator.get_all_modifiers(:homunculus, @gid)

    assert Map.take(modifiers, [:str, :agi, :vit, :int, :dex, :luk]) ==
             %{str: 39, agi: 0, vit: 0, int: 0, dex: 0, luk: 0}
  end

  defp pair_with_homunculus(link) do
    homunculus = %HomunculusState{
      id: 1,
      world_gid: @gid,
      owner_character_id: 17,
      owner_session_pid: self(),
      class_id: 6_001,
      name: "Lif",
      lifecycle: :active,
      level: 50,
      hp: 1_000,
      max_hp: 1_000,
      sp: 100,
      max_sp: 100,
      str: 60,
      agi: 10,
      vit: 0,
      int: 10,
      dex: 10,
      luk: 0,
      map_name: "prontera",
      x: 100,
      y: 100,
      action_state: :idle,
      movement_state: :standing
    }

    :ok = UnitRegistry.register_unit(:homunculus, @gid, HomunculusState, homunculus, self())

    :ok =
      SpatialIndex.add_unit(:homunculus, @gid, homunculus.x, homunculus.y, homunculus.map_name)

    halves = Formulas.marionette_halves(%{str: 80})
    gains = Formulas.marionette_gains(halves, %{str: 60})

    :ok =
      Interpreter.apply_status(:player, 17, :sc_marionette,
        caster_id: 17,
        duration: nil,
        state: %{peer: {:homunculus, @gid}, link_id: link, halves: halves}
      )

    :ok =
      Interpreter.apply_status(:homunculus, @gid, :sc_marionette2,
        caster_id: 17,
        duration: nil,
        state: %{peer: {:player, 17}, link_id: link, gains: gains}
      )
  end

  defp pair(link) do
    halves = Formulas.marionette_halves(%{str: 80})
    gains = Formulas.marionette_gains(halves, %{str: 60})

    :ok =
      Interpreter.apply_status(:player, 17, :sc_marionette,
        caster_id: 17,
        duration: nil,
        state: %{peer: {:player, 18}, link_id: link, halves: halves}
      )

    :ok =
      Interpreter.apply_status(:player, 18, :sc_marionette2,
        caster_id: 17,
        duration: nil,
        state: %{peer: {:player, 17}, link_id: link, gains: gains}
      )
  end
end
