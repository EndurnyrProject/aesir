defmodule Aesir.ZoneServer.ConfigTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Config

  test "pet configuration defaults match the shipped battle configuration when unset" do
    defaults = [
      {:pet_legacy_formula, :pet_legacy_formula?, false},
      {:pet_catch_rate, :pet_catch_rate, 100},
      {:pet_distance_check, :pet_distance_check, 5},
      {:pet_hide_check, :pet_hide_check?, true},
      {:pet_rename, :pet_rename?, false},
      {:pet_friendly_rate, :pet_friendly_rate, 100},
      {:pet_hungry_delay_rate, :pet_hungry_delay_rate, 100},
      {:pet_equip_required, :pet_equip_required?, true},
      {:pet_unequip_destroy, :pet_unequip_destroy?, true},
      {:pet_attack_support, :pet_attack_support?, false},
      {:pet_damage_support, :pet_damage_support?, false},
      {:pet_support_min_friendly, :pet_support_min_friendly, 900},
      {:pet_status_support, :pet_status_support?, false},
      {:pet_support_rate, :pet_support_rate, 100},
      {:pet_attack_exp_to_master, :pet_attack_exp_to_master?, false},
      {:pet_attack_exp_rate, :pet_attack_exp_rate, 100},
      {:pet_lv_rate, :pet_lv_rate, 0},
      {:pet_max_stats, :pet_max_stats, 99},
      {:pet_max_atk1, :pet_max_atk1, 500},
      {:pet_max_atk2, :pet_max_atk2, 1000},
      {:pet_disable_in_gvg, :pet_disable_in_gvg?, false},
      {:pet_ignore_infinite_def, :pet_ignore_infinite_def?, true},
      {:pet_master_dead, :pet_master_dead?, false},
      {:pet_autofeed_always, :pet_autofeed_always?, true},
      {:pet_walk_speed, :pet_walk_speed, 1},
      {:feature_pet_evolution, :feature_pet_evolution?, true},
      {:feature_pet_autofeed, :feature_pet_autofeed?, true},
      {:feature_pet_autofeed_rate, :feature_pet_autofeed_rate, 89}
    ]

    previous =
      Enum.map(defaults, fn {key, _, _} -> {key, Application.fetch_env(:zone_server, key)} end)

    on_exit(fn ->
      for {key, value} <- previous do
        case value do
          {:ok, configured} -> Application.put_env(:zone_server, key, configured)
          :error -> Application.delete_env(:zone_server, key)
        end
      end
    end)

    for {key, accessor, expected} <- defaults do
      Application.delete_env(:zone_server, key)
      assert apply(Config, accessor, []) == expected
    end
  end

  describe "max_party/0" do
    test "returns the configured default when unset" do
      assert Config.max_party() == 12
    end
  end

  describe "party_share_level/0" do
    test "returns the configured default when unset" do
      assert Config.party_share_level() == 15
    end
  end

  describe "party_even_share_bonus/0" do
    test "returns the configured default when unset" do
      assert Config.party_even_share_bonus() == 0
    end
  end

  describe "exp_bonus_attacker/0" do
    test "returns the configured default when unset" do
      assert Config.exp_bonus_attacker() == 25
    end
  end

  describe "boss_respawn_delay_percentage/0" do
    test "returns the configured default when unset" do
      assert Config.boss_respawn_delay_percentage() == 100
    end
  end

  describe "exp_bonus_max_attacker/0" do
    test "returns the configured default when unset" do
      assert Config.exp_bonus_max_attacker() == 12
    end
  end

  describe "woe_castle_mobs_on_boot?/0" do
    test "is disabled under the test config" do
      refute Config.woe_castle_mobs_on_boot?()
    end

    test "defaults to true with no app env set" do
      previous = Application.get_env(:zone_server, :woe_castle_mobs_on_boot)
      Application.delete_env(:zone_server, :woe_castle_mobs_on_boot)

      on_exit(fn ->
        case previous do
          nil -> Application.delete_env(:zone_server, :woe_castle_mobs_on_boot)
          value -> Application.put_env(:zone_server, :woe_castle_mobs_on_boot, value)
        end
      end)

      assert Config.woe_castle_mobs_on_boot?()
    end
  end

  describe "chat_room_gm_level/0" do
    test "defaults to 60 and reads the configured value" do
      previous = Application.get_env(:zone_server, :chat_room_gm_level)
      Application.delete_env(:zone_server, :chat_room_gm_level)

      on_exit(fn ->
        case previous do
          nil -> Application.delete_env(:zone_server, :chat_room_gm_level)
          value -> Application.put_env(:zone_server, :chat_room_gm_level, value)
        end
      end)

      assert Config.chat_room_gm_level() == 60

      Application.put_env(:zone_server, :chat_room_gm_level, 10)
      assert Config.chat_room_gm_level() == 10
    end
  end

  describe "natural_break_rate/0" do
    test "returns the configured default when unset" do
      assert Config.natural_break_rate() == 0
    end
  end

  describe "exp rate accessors" do
    test "default to 100 (1x) when unset" do
      assert Config.base_exp_rate() == 100
      assert Config.job_exp_rate() == 100
      assert Config.mvp_exp_rate() == 100
      assert Config.quest_exp_rate() == 100
    end
  end

  describe "guild progression accessors" do
    test "use the shipped guild defaults" do
      assert Config.guild_exp_rate() == 100
      assert Config.guild_exp_limit() == 50
      assert Config.guild_aura_affects_master() == false
    end
  end

  describe "drop_category/1" do
    test "classifies item types following rAthena" do
      assert Config.drop_category(:healing) == :heal
      assert Config.drop_category(:usable) == :use
      assert Config.drop_category(:cash) == :use
      assert Config.drop_category(:weapon) == :equip
      assert Config.drop_category(:armor) == :equip
      assert Config.drop_category(:pet_armor) == :equip
      assert Config.drop_category(:card) == :card
      assert Config.drop_category(:etc) == :common
      assert Config.drop_category(:pet_egg) == :common
      assert Config.drop_category(:ammo) == :common
      assert Config.drop_category(:delay_consume) == :common
    end
  end

  describe "item_drop_rate/1 and item_drop_bounds/1" do
    test "default to 1x rate and the 1..10000 clamp for every category" do
      for category <- [:common, :heal, :use, :equip, :card, :mvp, :treasure] do
        assert Config.item_drop_rate(category) == 100
        assert Config.item_drop_bounds(category) == {1, 10_000}
      end
    end
  end

  describe "level cap accessors" do
    test "default high enough to leave the per-job tables in charge" do
      assert Config.max_base_level() == 999
      assert Config.max_job_level() == 999
    end
  end
end
