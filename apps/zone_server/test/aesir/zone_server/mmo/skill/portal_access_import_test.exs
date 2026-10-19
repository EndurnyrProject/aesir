defmodule Aesir.ZoneServer.Mmo.Skill.PortalAccessImportTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Aesir.Import.PortalAccess

  @tag :tmp_dir
  test "follows only the selected mode graph and resolves inherited warp permission", %{
    tmp_dir: root
  } do
    for dir <- ["npc/re", "npc/pre-re", "db/re", "db/pre-re", "conf"] do
      File.mkdir_p!(Path.join(root, dir))
    end

    File.write!(Path.join(root, "npc/re/scripts_main.conf"), "import: npc/re/maps.conf\n")

    File.write!(
      Path.join(root, "npc/re/maps.conf"),
      "//npc: npc/disabled.txt\nnpc: npc/shared.txt\nnpc: npc/re/maps.txt\n"
    )

    File.write!(Path.join(root, "npc/pre-re/scripts_main.conf"), "npc: npc/shared.txt\n")
    File.write!(Path.join(root, "npc/shared.txt"), "prontera\tmapflag\tnomemo\n")

    File.write!(
      Path.join(root, "npc/re/maps.txt"),
      "prontera\tmapflag\tnomemo\toff\nizlude\tmapflag\trestricted\t8\n"
    )

    File.write!(Path.join(root, "db/re/job_noenter_map.txt"), "JOB_RUNE_KNIGHT,4112,100\n")
    File.write!(Path.join(root, "db/pre-re/job_noenter_map.txt"), "// no job restrictions\n")

    File.write!(Path.join(root, "conf/groups.yml"), """
    Body:
      - Id: 0
        Name: Player
      - Id: 3
        Name: Parent
        Permissions:
          any_warp: true
      - Id: 4
        Name: Child
        Level: 1
        Inherit:
          Parent: true
      - Id: 5
        Name: Refused
        Inherit:
          Parent: true
        Permissions:
          any_warp: false
    """)

    renewal = PortalAccess.build(root, :renewal)
    classic = PortalAccess.build(root, :pre_renewal)
    assert renewal["maps"]["prontera"] == %{"nomemo" => false}
    assert renewal["maps"]["izlude"] == %{"zone" => 4096}
    assert classic["maps"] == %{"prontera" => %{"nomemo" => true}}
    assert classic["jobs"] == %{}
    assert renewal["jobs"]["4054"] == %{"zone" => 4112, "group_level" => 100}
    assert renewal["groups"]["4"] == %{"any_warp" => true, "level" => 1}
    assert renewal["groups"]["5"]["any_warp"] == true
  end
end
