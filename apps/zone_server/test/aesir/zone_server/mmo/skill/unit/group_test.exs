defmodule Aesir.ZoneServer.Mmo.Skill.Unit.GroupTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group

  describe "visible_to?/3" do
    test "public groups are visible to every observer" do
      assert Group.visible_to?(group(:public), 2, nil)
    end

    test "none groups are visible to nobody, including their caster" do
      refute Group.visible_to?(group(:none), 1, 10)
    end

    test "party-only groups are visible to their player caster without a party" do
      assert Group.visible_to?(group(:party_only, party_id: 0), 1, nil)
    end

    test "party-only groups are visible to members of the snapshotted party" do
      assert Group.visible_to?(group(:party_only, party_id: 10), 2, 10)
    end

    test "party-only groups are hidden from unrelated and party-less observers" do
      refute Group.visible_to?(group(:party_only, party_id: 10), 2, 20)
      refute Group.visible_to?(group(:party_only, party_id: 10), 2, nil)
      refute Group.visible_to?(group(:party_only, party_id: 0), 2, 0)
    end

    test "a mob caster does not gain caster visibility" do
      refute Group.visible_to?(group(:party_only, caster_type: :mob), 1, nil)
    end
  end

  defp group(visibility, overrides \\ []) do
    struct!(
      Group,
      Keyword.merge(
        [
          group_id: 1,
          skill_name: :ht_landmine,
          visibility: visibility,
          caster_id: 1,
          caster_type: :player
        ],
        overrides
      )
    )
  end
end
