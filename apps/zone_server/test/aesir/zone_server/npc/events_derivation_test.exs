defmodule Aesir.ZoneServer.Npc.EventsDerivationTest do
  use ExUnit.Case, async: true

  defmodule WithEvents do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 150, y: 150, dir: 0, sprite: 58, name: "T"}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnStart", ctx), do: ctx
    def on_event("OnTimer1000", ctx), do: ctx
  end

  defmodule WithoutEvents do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 151, y: 151, dir: 0, sprite: 58, name: "T2"}]

    @impl true
    def on_talk(ctx), do: ctx
  end

  defmodule WithDuplicateEvent do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 152, y: 152, dir: 0, sprite: 58, name: "T3"}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnTouch", %{flag: true} = ctx), do: ctx
    def on_event("OnTouch", ctx), do: ctx
  end

  defmodule WithExplicitEvents do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 153, y: 153, dir: 0, sprite: 58, name: "T4"}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnStart", ctx), do: ctx

    @impl true
    def events, do: ["CustomOverride"]
  end

  defmodule WithExplicitEventsAndNoOnEvent do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 154, y: 154, dir: 0, sprite: 58, name: "T5"}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def events, do: ["ExplicitOnly"]
  end

  describe "events/0 derivation" do
    test "derives literal event labels from on_event/2 clauses, preserving order" do
      assert WithEvents.events() == ["OnStart", "OnTimer1000"]
    end

    test "defaults to [] when the module has no on_event/2 clauses" do
      assert WithoutEvents.events() == []
    end

    test "dedupes repeated event labels" do
      assert WithDuplicateEvent.events() == ["OnTouch"]
    end

    test "an explicit events/0 override wins over derivation" do
      assert WithExplicitEvents.events() == ["CustomOverride"]
    end

    test "an explicit events/0 override works even with no on_event/2 clauses at all" do
      assert WithExplicitEventsAndNoOnEvent.events() == ["ExplicitOnly"]
    end

    test "raises a CompileError naming the module for a non-literal clause head" do
      source = """
      defmodule Aesir.ZoneServer.Npc.EventsDerivationTest.BadNpc do
        use Aesir.ZoneServer.Npc,
          spawn: [%{map: "prontera", x: 160, y: 160, dir: 0, sprite: 58, name: "Bad"}]

        @impl true
        def on_talk(ctx), do: ctx

        def on_event(label, ctx) when is_binary(label), do: ctx
      end
      """

      assert_raise CompileError, ~r/BadNpc/, fn ->
        Code.compile_string(source)
      end
    end
  end
end
