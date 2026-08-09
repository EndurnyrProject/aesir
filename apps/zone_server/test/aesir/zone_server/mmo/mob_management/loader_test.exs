defmodule Aesir.ZoneServer.Mmo.MobManagement.LoaderTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.MobManagement.Loader
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition

  @mob_yaml """
  - id: 1
    aegis_name: TEST_MOB
    name: Test Mob
    level: 1
    hp: 1
    stats: {}
    attack_range: 1
    size: small
    race: plant
    element: water
    walk_speed: 1
    attack_delay: 1
    attack_motion: 1
    client_attack_motion: 1
    damage_motion: 1
  """

  defp write_yaml(dir, contents) do
    File.write!(Path.join(dir, "mobs.yml"), contents)
  end

  test "MobDefinition race_groups defaults to an empty list" do
    definition =
      struct!(MobDefinition, %{
        id: 1,
        aegis_name: "TEST_MOB",
        name: "Test Mob",
        level: 1,
        hp: 1,
        stats: %{},
        attack_range: 1,
        size: :small,
        race: :plant,
        element: {:water, 1},
        walk_speed: 1,
        attack_delay: 1,
        attack_motion: 1,
        client_attack_motion: 1,
        damage_motion: 1
      })

    assert definition.race_groups == []
  end

  @tag :tmp_dir
  test "decodes race_groups from YAML", %{tmp_dir: dir} do
    write_yaml(dir, @mob_yaml <> "  race_groups:\n    - golem\n")

    assert %{by_id: %{1 => %MobDefinition{race_groups: [:golem]}}} = Loader.load(dir)
  end

  @tag :tmp_dir
  test "defaults race_groups when YAML omits it", %{tmp_dir: dir} do
    write_yaml(dir, @mob_yaml)

    assert %{by_id: %{1 => %MobDefinition{race_groups: []}}} = Loader.load(dir)
  end
end
