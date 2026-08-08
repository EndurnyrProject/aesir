defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaSpellbreakerTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Sage.SaSpellbreaker
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.MagicRod
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context

  @caster_id 1000
  @target_id 2000
  # MG_FIREBOLT: in the player catalog, so it has a real SP cost to drain.
  @firebolt %{skill: "MG_FIREBOLT", skill_id: 19, level: 5}

  defp caster(sp, max_sp, opts \\ []) do
    %PlayerState{
      character_id: @caster_id,
      stats: %{
        current_state: %{sp: sp, hp: Keyword.get(opts, :hp, 500)},
        derived_stats: %{max_sp: max_sp, max_hp: Keyword.get(opts, :max_hp, 1_000)}
      }
    }
  end

  defp mob_state(opts) do
    %MobState{
      instance_id: @target_id,
      mob_id: 1_002,
      mob_data: %{modes: Keyword.get(opts, :modes, [])},
      spawn_ref: nil,
      map_name: "prontera",
      x: 100,
      y: 100,
      hp: Keyword.get(opts, :hp, 1_000),
      max_hp: Keyword.get(opts, :max_hp, 1_000),
      sp: 100,
      max_sp: 100,
      spawned_at: 0,
      is_dead: Keyword.get(opts, :is_dead, false),
      casting: Keyword.get(opts, :casting)
    }
  end

  # Resolves the target as a mob whose session reports `states` in order, one per
  # `get_state/1` call (the skill reads again after the interrupt to revalidate).
  defp stub_mob(states) when is_list(states) do
    pid = self()
    stub(UnitRegistry, :get_unit, fn :mob, @target_id -> {:ok, {MobState, hd(states), pid}} end)

    {:ok, agent} = Agent.start_link(fn -> states end)

    stub(MobSession, :get_state, fn ^pid ->
      Agent.get_and_update(agent, fn
        [last] -> {last, [last]}
        [head | rest] -> {head, rest}
      end)
    end)

    pid
  end

  defp stub_mob(state), do: stub_mob([state])

  defp no_magic_rod do
    stub(StatusStorage, :has_status?, fn _type, _id, :sc_magicrod -> false end)
  end

  describe "catalog registration" do
    test "by_id/1 resolves id 277" do
      assert {:ok, %{name: :sa_spellbreaker}} = Catalog.by_id(277)
    end

    test "active_module_for/1 resolves the module" do
      assert {:ok, SaSpellbreaker} = Catalog.active_module_for(:sa_spellbreaker)
    end
  end

  describe "metadata" do
    test "matches the rAthena renewal table" do
      {:ok, definition} = Catalog.by_name(:sa_spellbreaker)

      assert definition.max_level == 5
      assert definition.target_type == :target_enemy
      assert definition.damage_type == :no_damage
      assert definition.damage_kind == :magic
      assert definition.range == 9
      assert definition.sp_cost == List.duplicate(10, 5)
      assert definition.cast_time == List.duplicate(560, 5)
      assert definition.fixed_cast_time == List.duplicate(140, 5)
    end
  end

  describe "cast/5 - target not casting" do
    test "fails with :not_casting and never interrupts" do
      stub_mob(mob_state(casting: nil))
      no_magic_rod()
      reject(&MobSession.interrupt_cast/1)

      assert {:error, :not_casting} =
               SaSpellbreaker.cast(caster(100, 100), {:unit, @target_id}, 5, nil)
    end

    test "leaves the caster's SP untouched" do
      stub_mob(mob_state(casting: nil))
      no_magic_rod()

      caster = caster(100, 100)
      assert {:error, :not_casting} = SaSpellbreaker.cast(caster, {:unit, @target_id}, 5, nil)
    end
  end

  describe "cast/5 - success" do
    setup do
      no_magic_rod()
      test_pid = self()

      stub(MobSession, :interrupt_cast, fn pid ->
        send(test_pid, {:interrupted, pid})
        {:ok, @firebolt}
      end)

      stub(MobSession, :zap_sp, fn _pid, amount ->
        send(test_pid, {:zapped_sp, amount})
        :ok
      end)

      stub(MobSession, :apply_damage, fn _pid, damage, source ->
        send(test_pid, {:damaged, damage, source})
        :ok
      end)

      :ok
    end

    test "interrupts the cast and zaps the interrupted skill's SP cost" do
      # MG_FIREBOLT lv5 costs 20 SP in the player catalog.
      pid = stub_mob(mob_state(casting: %{row: @firebolt}))

      assert {:ok, _caster} = SaSpellbreaker.cast(caster(100, 200), {:unit, @target_id}, 1, nil)

      assert_received {:interrupted, ^pid}
      assert_received {:zapped_sp, 20}
    end

    test "heals the caster sp * 25*(lv-1) / 100" do
      stub_mob(mob_state(casting: %{row: @firebolt}))

      # lv3: 20 * (25 * 2) / 100 = 10 SP.
      assert {:ok, caster} = SaSpellbreaker.cast(caster(100, 200), {:unit, @target_id}, 3, nil)
      assert caster.stats.current_state.sp == 110
    end

    test "heals the caster nothing at level 1" do
      stub_mob(mob_state(casting: %{row: @firebolt}))

      assert {:ok, caster} = SaSpellbreaker.cast(caster(100, 200), {:unit, @target_id}, 1, nil)
      assert caster.stats.current_state.sp == 100
    end

    test "clamps the caster's SP heal at max SP" do
      stub_mob(mob_state(casting: %{row: @firebolt}))

      # lv5: 20 * 100 / 100 = 20 SP, but only 5 SP of room.
      assert {:ok, caster} = SaSpellbreaker.cast(caster(95, 100), {:unit, @target_id}, 5, nil)
      assert caster.stats.current_state.sp == 100
    end

    test "zaps nothing for a mob-only skill absent from the player catalog" do
      npc_skill = %{skill: "NPC_FIREATTACK", skill_id: 186, level: 5}
      stub_mob(mob_state(casting: %{row: npc_skill}))
      stub(MobSession, :interrupt_cast, fn _pid -> {:ok, npc_skill} end)

      assert {:ok, caster} = SaSpellbreaker.cast(caster(100, 200), {:unit, @target_id}, 5, nil)

      assert_received {:zapped_sp, 0}
      assert caster.stats.current_state.sp == 100
    end

    test "extrapolates the SP cost when the mob casts above the skill's max level" do
      # Mob rows really do exceed the player table (AL_DECAGI lv 48). The SP cost
      # projects past the level-10 table from its last three entries
      # (29, 31, 33) rather than clamping: 33 + 39 + 38 = 110.
      overlevelled = %{skill: "AL_DECAGI", skill_id: 30, level: 48}
      stub_mob(mob_state(casting: %{row: overlevelled}))
      stub(MobSession, :interrupt_cast, fn _pid -> {:ok, overlevelled} end)

      assert {:ok, _caster} = SaSpellbreaker.cast(caster(100, 500), {:unit, @target_id}, 5, nil)
      assert_received {:zapped_sp, 110}
    end
  end

  describe "cast/5 - level 5 HP siphon" do
    setup do
      no_magic_rod()
      test_pid = self()

      stub(MobSession, :interrupt_cast, fn _pid -> {:ok, @firebolt} end)
      stub(MobSession, :zap_sp, fn _pid, _amount -> :ok end)

      stub(MobSession, :apply_damage, fn _pid, damage, source ->
        send(test_pid, {:damaged, damage, source})
        :ok
      end)

      :ok
    end

    test "deals max_hp/50 and heals the caster half of it" do
      stub_mob(mob_state(casting: %{row: @firebolt}, hp: 1_000, max_hp: 1_000))

      assert {:ok, caster} = SaSpellbreaker.cast(caster(100, 200), {:unit, @target_id}, 5, nil)

      assert_received {:damaged, 20, @caster_id}
      assert caster.stats.current_state.hp == 510
    end

    test "does not siphon below level 5" do
      stub_mob(mob_state(casting: %{row: @firebolt}, hp: 1_000, max_hp: 1_000))

      assert {:ok, caster} = SaSpellbreaker.cast(caster(100, 200), {:unit, @target_id}, 4, nil)

      refute_received {:damaged, _damage, _source}
      assert caster.stats.current_state.hp == 500
    end

    test "skips the hit when it would be lethal" do
      # max_hp/50 = 20 and the mob sits on exactly 20 HP: `hp < tstatus->hp` is
      # false, so the reference deals nothing rather than killing the target.
      stub_mob(mob_state(casting: %{row: @firebolt}, hp: 20, max_hp: 1_000))

      assert {:ok, caster} = SaSpellbreaker.cast(caster(100, 200), {:unit, @target_id}, 5, nil)

      refute_received {:damaged, _damage, _source}
      assert caster.stats.current_state.hp == 500
    end

    test "skips the hit when the mob has less HP than the siphon" do
      stub_mob(mob_state(casting: %{row: @firebolt}, hp: 19, max_hp: 1_000))

      assert {:ok, _caster} = SaSpellbreaker.cast(caster(100, 200), {:unit, @target_id}, 5, nil)
      refute_received {:damaged, _damage, _source}
    end

    test "deals the hit when it leaves the mob alive by one HP" do
      stub_mob(mob_state(casting: %{row: @firebolt}, hp: 21, max_hp: 1_000))

      assert {:ok, _caster} = SaSpellbreaker.cast(caster(100, 200), {:unit, @target_id}, 5, nil)
      assert_received {:damaged, 20, @caster_id}
    end

    test "skips the hit when max_hp is too small to siphon" do
      stub_mob(mob_state(casting: %{row: @firebolt}, hp: 49, max_hp: 49))

      assert {:ok, _caster} = SaSpellbreaker.cast(caster(100, 200), {:unit, @target_id}, 5, nil)
      refute_received {:damaged, _damage, _source}
    end

    test "skips the hit when the mob died between the interrupt and the siphon" do
      stub_mob([
        mob_state(casting: %{row: @firebolt}, hp: 1_000, max_hp: 1_000),
        mob_state(casting: %{row: @firebolt}, hp: 0, max_hp: 1_000, is_dead: true)
      ])

      assert {:ok, _caster} = SaSpellbreaker.cast(caster(100, 200), {:unit, @target_id}, 5, nil)
      refute_received {:damaged, _damage, _source}
    end
  end

  describe "cast/5 - boss-moded target" do
    setup do
      no_magic_rod()
      test_pid = self()

      stub(MobSession, :interrupt_cast, fn pid ->
        send(test_pid, {:interrupted, pid})
        {:ok, @firebolt}
      end)

      stub(MobSession, :zap_sp, fn _pid, _amount -> :ok end)

      stub(MobSession, :apply_damage, fn _pid, damage, source ->
        send(test_pid, {:damaged, damage, source})
        :ok
      end)

      :ok
    end

    test "fails on a roll inside the 90% window, leaving the cast running" do
      stub_mob(mob_state(casting: %{row: @firebolt}, modes: [:boss]))

      assert {:error, :failed} =
               SaSpellbreaker.cast(caster(100, 200), {:unit, @target_id}, 5, nil,
                 rng: fn 100 -> 90 end
               )

      refute_received {:interrupted, _pid}
    end

    test "succeeds on a roll above the 90% window" do
      stub_mob(mob_state(casting: %{row: @firebolt}, modes: [:boss]))
      pid = self()

      assert {:ok, _caster} =
               SaSpellbreaker.cast(caster(100, 200), {:unit, @target_id}, 5, nil,
                 rng: fn 100 -> 91 end
               )

      assert_received {:interrupted, ^pid}
    end

    test "never siphons HP from a boss, even at level 5" do
      stub_mob(mob_state(casting: %{row: @firebolt}, modes: [:boss], hp: 1_000, max_hp: 1_000))

      assert {:ok, caster} =
               SaSpellbreaker.cast(caster(100, 200), {:unit, @target_id}, 5, nil,
                 rng: fn 100 -> 91 end
               )

      refute_received {:damaged, _damage, _source}
      assert caster.stats.current_state.hp == 500
    end

    test "a non-boss target never rolls at all" do
      stub_mob(mob_state(casting: %{row: @firebolt}))

      assert {:ok, _caster} =
               SaSpellbreaker.cast(caster(100, 200), {:unit, @target_id}, 5, nil,
                 rng: fn _ -> flunk("a non-boss target must not roll") end
               )
    end
  end

  describe "cast/5 - target under Magic Rod" do
    setup do
      test_pid = self()

      # Bound to the status Task 20 actually declares, not a literal.
      stub(StatusStorage, :has_status?, fn type, id, status ->
        send(test_pid, {:queried, type, id, status})
        status == MagicRod.id()
      end)

      stub(Helpers, :restore_sp, fn target, amount ->
        send(test_pid, {:restored, target, amount})
        :ok
      end)

      :ok
    end

    test "transfers 20% of the caster's max SP to the target and does nothing else" do
      stub_mob(mob_state(casting: %{row: @firebolt}))
      reject(&MobSession.interrupt_cast/1)
      reject(&MobSession.zap_sp/2)
      reject(&MobSession.apply_damage/3)

      assert {:ok, caster} = SaSpellbreaker.cast(caster(100, 200), {:unit, @target_id}, 5, nil)

      assert_received {:queried, :mob, @target_id, :sc_magicrod}
      assert_received {:restored, {:mob, @target_id}, 40}
      assert caster.stats.current_state.sp == 60
    end

    test "transfers no more SP than the caster has" do
      stub_mob(mob_state(casting: %{row: @firebolt}))

      assert {:ok, caster} = SaSpellbreaker.cast(caster(10, 200), {:unit, @target_id}, 5, nil)

      assert_received {:restored, {:mob, @target_id}, 10}
      assert caster.stats.current_state.sp == 0
    end

    test "wins even when the target is not casting" do
      stub_mob(mob_state(casting: nil))

      assert {:ok, caster} = SaSpellbreaker.cast(caster(100, 200), {:unit, @target_id}, 5, nil)
      assert caster.stats.current_state.sp == 60
    end
  end

  describe "cast/5 - target resolution" do
    test "a player target is PvP-blocked" do
      stub(UnitRegistry, :get_unit, fn
        :mob, @target_id ->
          {:error, :not_found}

        :player, @target_id ->
          {:ok, {PlayerState, %PlayerState{character_id: @target_id}, self()}}
      end)

      assert {:error, :invalid_target} =
               SaSpellbreaker.cast(caster(100, 200), {:unit, @target_id}, 5, nil)
    end

    test "an absent target fails cleanly" do
      stub(UnitRegistry, :get_unit, fn _type, @target_id -> {:error, :not_found} end)

      assert {:error, :target_not_found} =
               SaSpellbreaker.cast(caster(100, 200), {:unit, @target_id}, 5, nil)
    end

    test "a dead mob is rejected before any interruption" do
      no_magic_rod()
      reject(&MobSession.interrupt_cast/1)
      stub_mob(mob_state(casting: %{row: @firebolt}, hp: 0, is_dead: true))

      assert {:error, :target_dead} =
               SaSpellbreaker.cast(caster(100, 200), {:unit, @target_id}, 5, nil)
    end
  end
end
