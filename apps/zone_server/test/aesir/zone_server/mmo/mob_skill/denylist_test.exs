defmodule Aesir.ZoneServer.Mmo.MobSkill.DenylistTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.MobSkill.Denylist
  alias Aesir.ZoneServer.Mmo.MobSkill.Importer
  alias Aesir.ZoneServer.Mmo.Skill.Catalog

  test "denied?/1 is false for an id never swept into the list" do
    refute Denylist.denied?(1)
    refute Denylist.denied?(19)
    refute Denylist.denied?(999_999)
  end

  test "denied?/1 and reason_for/1 agree for a real sweep-populated entry" do
    assert Denylist.denied?(8)
    assert Denylist.reason_for(8) =~ "SM_ENDURE"
  end

  test "denied?/1 and reason_for/1 agree for HT_TALKIEBOX, which resolves in the catalog" do
    assert {:ok, definition} = Catalog.by_id(125)
    assert {:ok, _module} = Catalog.active_module_for(definition.name)

    assert Denylist.denied?(125)
    assert Denylist.reason_for(125) =~ "HT_TALKIEBOX"
  end

  test "retained Bard denials name their concrete player-only dependency" do
    expected_fragments = %{
      304 => ["BD_ADAPTATION", "character_id", "player status"],
      305 => ["BD_ENCORE", "last_song", "learned-skill"]
    }

    for {skill_id, fragments} <- expected_fragments do
      assert {:ok, definition} = Catalog.by_id(skill_id)
      assert {:ok, _module} = Catalog.active_module_for(definition.name)
      assert Denylist.denied?(skill_id)

      reason = Denylist.reason_for(skill_id)
      Enum.each(fragments, &assert(reason =~ &1))
    end

    expected_song_reasons = %{
      319 => "BA_WHISTLE requires a PlayerState party snapshot; there is no mob-caster clause",
      320 =>
        "BA_ASSASSINCROSS requires a PlayerState party snapshot; there is no mob-caster clause",
      321 => "BA_POEMBRAGI requires a PlayerState party snapshot; there is no mob-caster clause",
      322 => "BA_APPLEIDUN requires a PlayerState party snapshot; there is no mob-caster clause"
    }

    for {skill_id, expected_reason} <- expected_song_reasons do
      assert {:ok, definition} = Catalog.by_id(skill_id)
      assert {:ok, _module} = Catalog.active_module_for(definition.name)
      assert Denylist.denied?(skill_id)
      assert Denylist.reason_for(skill_id) == expected_reason
    end
  end

  test "ensembles state their PlayerState snapshot and partner lookup dependency" do
    expected_reasons = %{
      306 =>
        "BD_LULLABY requires a PlayerState snapshot and partner lookup; there is no mob-caster clause",
      307 =>
        "BD_RICHMANKIM requires a PlayerState snapshot and partner lookup; there is no mob-caster clause",
      308 =>
        "BD_ETERNALCHAOS requires a PlayerState snapshot and partner lookup; there is no mob-caster clause",
      309 =>
        "BD_DRUMBATTLEFIELD requires a PlayerState snapshot and partner lookup; there is no mob-caster clause",
      310 =>
        "BD_RINGNIBELUNGEN requires a PlayerState snapshot and partner lookup; there is no mob-caster clause",
      311 =>
        "BD_ROKISWEIL requires a PlayerState snapshot and partner lookup; there is no mob-caster clause",
      312 =>
        "BD_INTOABYSS requires a PlayerState snapshot and partner lookup; there is no mob-caster clause",
      313 =>
        "BD_SIEGFRIED requires a PlayerState snapshot and partner lookup; there is no mob-caster clause"
    }

    for {skill_id, expected_reason} <- expected_reasons do
      assert {:ok, definition} = Catalog.by_id(skill_id)
      assert {:ok, _module} = Catalog.active_module_for(definition.name)
      assert Denylist.denied?(skill_id)
      assert Denylist.reason_for(skill_id) == expected_reason
    end
  end

  test "caster-generic Bard skills remain mob-available" do
    for skill_id <- [316, 317, 318, 1010] do
      assert {:ok, definition} = Catalog.by_id(skill_id)
      assert {:ok, _module} = Catalog.active_module_for(definition.name)
      refute Denylist.denied?(skill_id)
      assert Denylist.reason_for(skill_id) == nil
    end
  end

  test "player-only Dancer skills state their concrete mob-caster dependency" do
    expected_reasons = %{
      327 => "DC_HUMMING requires a PlayerState party snapshot; there is no mob-caster clause",
      328 =>
        "DC_DONTFORGETME requires a PlayerState enemy snapshot; there is no mob-caster clause",
      329 =>
        "DC_FORTUNEKISS requires a PlayerState party snapshot; there is no mob-caster clause",
      330 =>
        "DC_SERVICEFORYOU requires a PlayerState party snapshot; there is no mob-caster clause",
      1011 =>
        "DC_WINKCHARM reads PlayerState caster level and applies a player-origin status; there is no mob-caster clause"
    }

    for {skill_id, expected_reason} <- expected_reasons do
      assert {:ok, definition} = Catalog.by_id(skill_id)
      assert {:ok, _module} = Catalog.active_module_for(definition.name)
      assert Denylist.denied?(skill_id)
      assert Denylist.reason_for(skill_id) == expected_reason
    end
  end

  test "caster-generic Dancer skills remain mob-available" do
    for skill_id <- [324, 325, 326] do
      assert {:ok, definition} = Catalog.by_id(skill_id)
      assert {:ok, _module} = Catalog.active_module_for(definition.name)
      refute Denylist.denied?(skill_id)
      assert Denylist.reason_for(skill_id) == nil
    end
  end

  test "exactly the thirteen active Homunculus skills are denied to mob casters" do
    active = [8001, 8002, 8004, 8005, 8006, 8008, 8009, 8010, 8011, 8012, 8013, 8014, 8016]
    passive = [8003, 8007, 8015]

    for skill_id <- active do
      assert {:ok, definition} = Catalog.by_id(skill_id)
      assert {:ok, _module} = Catalog.active_module_for(definition.name)
      assert Denylist.denied?(skill_id)
      assert Denylist.reason_for(skill_id) =~ "Homunculus"
    end

    for skill_id <- passive do
      assert {:ok, definition} = Catalog.by_id(skill_id)
      assert :error = Catalog.active_module_for(definition.name)
      refute Denylist.denied?(skill_id)
      assert Denylist.reason_for(skill_id) == nil
    end
  end

  test "importer classification and current YAML rows preserve the exact Homunculus split" do
    active = [8001, 8002, 8004, 8005, 8006, 8008, 8009, 8010, 8011, 8012, 8013, 8014, 8016]
    passive = [8003, 8007, 8015]

    assert Enum.all?(active, &match?({:denylisted, _reason}, Importer.classify(&1)))
    assert Enum.all?(passive, &(Importer.classify(&1) == :unresolved))

    path = Application.app_dir(:zone_server, "priv/db/mob_skills/mob_skills.yml")

    imported_skill_ids =
      path
      |> YamlElixir.read_from_file!()
      |> Map.values()
      |> List.flatten()
      |> Enum.map(& &1["skill_id"])
      |> MapSet.new()

    assert MapSet.disjoint?(imported_skill_ids, MapSet.new(8001..8016))
  end
end
