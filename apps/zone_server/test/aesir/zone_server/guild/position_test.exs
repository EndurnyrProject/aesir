defmodule Aesir.ZoneServer.Guild.PositionTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.GuildPosition
  alias Aesir.ZoneServer.Guild.Position

  describe "defaults/0" do
    test "returns 20 positions indexed 0..19" do
      defaults = Position.defaults()

      assert length(defaults) == 20
      assert Enum.map(defaults, & &1.index) == Enum.to_list(0..19)
    end

    test "index 0 is GuildMaster with invite and expel" do
      master = Enum.at(Position.defaults(), 0)

      assert master.name == "GuildMaster"
      assert master.can_invite
      assert master.can_expel
    end

    test "index 19 is Newbie with no flags" do
      newbie = Enum.at(Position.defaults(), 19)

      assert newbie.name == "Newbie"
      refute newbie.can_invite
      refute newbie.can_expel
    end

    test "indexes 1..18 are blank with no flags" do
      for index <- 1..18 do
        position = Enum.at(Position.defaults(), index)

        assert position.name == ""
        refute position.can_invite
        refute position.can_expel
      end
    end
  end

  describe "from_model/1" do
    test "maps a GuildPosition row into a Position" do
      model = %GuildPosition{
        guild_id: 1,
        index: 3,
        name: "Officer",
        can_invite: true,
        can_expel: false,
        can_storage: true,
        tax: 5
      }

      position = Position.from_model(model)

      assert position.index == 3
      assert position.name == "Officer"
      assert position.can_invite
      refute position.can_expel
      assert position.can_storage
      assert position.tax == 5
    end

    test "coerces a nil name into an empty string" do
      model = %GuildPosition{guild_id: 1, index: 5, name: nil}

      assert Position.from_model(model).name == ""
    end
  end
end
