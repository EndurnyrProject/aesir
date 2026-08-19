defmodule Aesir.ZoneServer.Mmo.Combat.AfterDamageTakenTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @victim_id 1
  @attacker_id 2

  defmodule ReflectStatus do
    @moduledoc false
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_reflect,
      no_dispel: false,
      properties: [:buff]

    @impl true
    def after_damage_taken(_target, _instance, hit_info, _context) do
      if Map.get(hit_info, :dmg_type) == :physical and Map.get(hit_info, :is_short, false) and
           not Map.get(hit_info, :reflected, false) and
           not Map.get(hit_info, :redirected, false),
         do: {:reflect, div(hit_info.damage, 2)},
         else: :ok
    end
  end

  defmodule InertStatus do
    @moduledoc false
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_inert_reflect,
      no_dispel: false,
      properties: [:buff]
  end

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  defp stub_unit_info(char_id) do
    stub(UnitRegistry, :get_unit_info, fn :player, ^char_id ->
      {:ok,
       %{
         unit_id: char_id,
         unit_type: :player,
         race: :formless,
         element: :neutral,
         element_level: 1,
         boss_flag: false,
         size: :medium,
         stats: %{
           max_hp: 100,
           max_sp: 50,
           hp: 100,
           sp: 50,
           level: 1,
           base_level: 1,
           str: 1,
           agi: 1,
           vit: 1,
           int: 1,
           dex: 1,
           luk: 1,
           mdef: 0
         }
       }}
    end)
  end

  # A raw process that answers the session apply_damage cast, forwarding the
  # delivered damage to the test process. Using a real cast target - rather than
  # a stub - proves the reflect path is asynchronous: a synchronous self-call
  # would deadlock this same process.
  defp spawn_session(label) do
    test_pid = self()
    spawn_link(fn -> session_loop(test_pid, label) end)
  end

  defp session_loop(test_pid, label) do
    receive do
      {:"$gen_cast", {:unit, {:apply_damage, damage, attacker_id}}} ->
        send(test_pid, {label, damage, attacker_id})
        session_loop(test_pid, label)

      _other ->
        session_loop(test_pid, label)
    end
  end

  defp arm_reflect(victim_pid, attacker_pid) do
    stub_unit_info(@victim_id)
    Registry.register_module(ReflectStatus)
    :ok = Interpreter.apply_status(:player, @victim_id, :sc_test_reflect)

    stub(TargetResolver, :resolve, fn @attacker_id ->
      {:ok, attacker_pid, %{}, :player}
    end)

    %{victim_pid: victim_pid, attacker_pid: attacker_pid}
  end

  defp melee_hit, do: %{dmg_type: :physical, is_short: true, element: :neutral}

  describe "after_damage_taken reflect hook" do
    test "reflects a fraction of a melee weapon hit back to the attacker asynchronously" do
      victim = spawn_session(:victim)
      attacker = spawn_session(:attacker)
      arm_reflect(victim, attacker)

      DamageApplication.apply_unit_damage(
        :player,
        victim,
        @victim_id,
        100,
        melee_hit(),
        @attacker_id
      )

      assert_receive {:victim, 100, {:player, @attacker_id}}
      assert_receive {:attacker, 50, nil}
    end

    test "does not dispatch for a hit already flagged reflected" do
      victim = spawn_session(:victim)
      attacker = spawn_session(:attacker)
      arm_reflect(victim, attacker)

      DamageApplication.apply_unit_damage(
        :player,
        victim,
        @victim_id,
        100,
        Map.put(melee_hit(), :reflected, true),
        @attacker_id
      )

      assert_receive {:victim, 100, {:player, @attacker_id}}
      refute_receive {:attacker, _, _}
    end

    test "does not dispatch for a hit flagged redirected" do
      victim = spawn_session(:victim)
      attacker = spawn_session(:attacker)
      arm_reflect(victim, attacker)

      DamageApplication.apply_unit_damage(
        :player,
        victim,
        @victim_id,
        100,
        Map.put(melee_hit(), :redirected, true),
        @attacker_id
      )

      assert_receive {:victim, 100, {:player, @attacker_id}}
      refute_receive {:attacker, _, _}
    end

    test "does not dispatch for a ranged weapon hit" do
      victim = spawn_session(:victim)
      attacker = spawn_session(:attacker)
      arm_reflect(victim, attacker)

      DamageApplication.apply_unit_damage(
        :player,
        victim,
        @victim_id,
        100,
        %{dmg_type: :physical, is_short: false, element: :neutral},
        @attacker_id
      )

      assert_receive {:victim, 100, {:player, @attacker_id}}
      refute_receive {:attacker, _, _}
    end

    test "does not dispatch for magic damage" do
      victim = spawn_session(:victim)
      attacker = spawn_session(:attacker)
      arm_reflect(victim, attacker)

      DamageApplication.apply_unit_damage(
        :player,
        victim,
        @victim_id,
        100,
        %{dmg_type: :magic, is_short: true, element: :neutral},
        @attacker_id
      )

      assert_receive {:victim, 100, {:player, @attacker_id}}
      refute_receive {:attacker, _, _}
    end

    test "an attacker reflecting onto itself does not deadlock" do
      # Same process is both victim and attacker: the reflect must be a cast, so
      # the call returns and both the hit and its reflection land in the mailbox.
      unit = spawn_session(:unit)
      stub_unit_info(@attacker_id)
      Registry.register_module(ReflectStatus)
      :ok = Interpreter.apply_status(:player, @attacker_id, :sc_test_reflect)

      stub(TargetResolver, :resolve, fn @attacker_id -> {:ok, unit, %{}, :player} end)

      assert :ok =
               DamageApplication.apply_unit_damage(
                 :player,
                 unit,
                 @attacker_id,
                 100,
                 melee_hit(),
                 @attacker_id
               )

      assert_receive {:unit, 100, {:player, @attacker_id}}
      assert_receive {:unit, 50, nil}
    end

    test "a victim status not implementing the hook reflects nothing" do
      victim = spawn_session(:victim)
      attacker = spawn_session(:attacker)
      stub_unit_info(@victim_id)
      Registry.register_module(InertStatus)
      :ok = Interpreter.apply_status(:player, @victim_id, :sc_test_inert_reflect)

      stub(TargetResolver, :resolve, fn @attacker_id -> {:ok, attacker, %{}, :player} end)

      DamageApplication.apply_unit_damage(
        :player,
        victim,
        @victim_id,
        100,
        melee_hit(),
        @attacker_id
      )

      assert_receive {:victim, 100, {:player, @attacker_id}}
      refute_receive {:attacker, _, _}
    end
  end
end
