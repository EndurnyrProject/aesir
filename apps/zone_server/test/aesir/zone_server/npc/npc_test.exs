defmodule Aesir.ZoneServer.NpcTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Npc.Placement

  defmodule SampleNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 150, y: 150, dir: 0, sprite: 58, name: "T"}]

    @impl true
    def on_talk(ctx), do: ctx
  end

  defmodule RenewalNpc do
    use Aesir.ZoneServer.Npc,
      scope: :renewal,
      spawn: [
        %{map: "prontera", x: 151, y: 151, dir: 0, sprite: 58, name: "Renewal"},
        %{
          map: "prontera",
          x: 152,
          y: 152,
          dir: 0,
          sprite: 58,
          name: "Pre-renewal",
          scope: :pre_renewal
        }
      ]

    @impl true
    def on_talk(ctx), do: ctx
  end

  describe "use Aesir.ZoneServer.Npc" do
    test "defaults content scope to shared" do
      assert SampleNpc.content_scope() == :shared
    end

    test "exposes an explicit body content scope" do
      assert RenewalNpc.content_scope() == :renewal
    end

    test "exposes a stable npc_id/0 atom" do
      assert is_atom(SampleNpc.npc_id())
      assert SampleNpc.npc_id() == SampleNpc.npc_id()
    end

    test "exposes spawn/0 normalized to Placement structs" do
      assert [%Placement{} = placement] = SampleNpc.spawn()

      assert placement.map == "prontera"
      assert placement.x == 150
      assert placement.y == 150
      assert placement.dir == 0
      assert placement.sprite == 58
      assert placement.name == "T"
    end

    test "inherits the body content scope for each placement" do
      assert [%Placement{scope: :renewal}, _placement] = RenewalNpc.spawn()
    end

    test "allows a placement to override the body content scope" do
      assert [_, %Placement{scope: :pre_renewal}] = RenewalNpc.spawn()
    end

    test "rejects an invalid body content scope at compile time" do
      source = """
      defmodule Aesir.ZoneServer.NpcTest.InvalidBodyScopeNpc do
        use Aesir.ZoneServer.Npc,
          scope: :classic,
          spawn: [%{map: "prontera", x: 153, y: 153, dir: 0, sprite: 58, name: "Invalid"}]

        @impl true
        def on_talk(ctx), do: ctx
      end
      """

      assert_raise ArgumentError, ~r/:classic/, fn ->
        Code.compile_string(source)
      end
    end

    test "rejects an invalid placement content scope at compile time" do
      source = """
      defmodule Aesir.ZoneServer.NpcTest.InvalidPlacementScopeNpc do
        use Aesir.ZoneServer.Npc,
          scope: :renewal,
          spawn: [
            %{
              map: "prontera",
              x: 154,
              y: 154,
              dir: 0,
              sprite: 58,
              name: "Invalid",
              scope: :classic
            }
          ]

        @impl true
        def on_talk(ctx), do: ctx
      end
      """

      assert_raise ArgumentError, ~r/:classic/, fn ->
        Code.compile_string(source)
      end
    end

    test "declares the Npc behaviour" do
      assert Aesir.ZoneServer.Npc in (SampleNpc.module_info(:attributes)[:behaviour] || [])
    end
  end
end
