defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsNiflheim.Piano3 do
  @moduledoc """
  The last empty key space of the Niflheim piano, which carries players who completed the
  keyboard out of the Niflheim house.

  ## Behavior

  - Touching it with the keyboard filled in (or after a previous escape) plays a chime and
    warps the player to the other side of the house.
  - The first escape records the Piano Key quest as done and clears the legacy piano variable.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - Evera
    - Lupus
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{name: "Piano3", scope: :shared},
      %{
        map: "nif_in",
        x: 118,
        y: 151,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :renewal,
        unique_name: "#Piano3",
        trigger: {1, 1}
      },
      %{
        map: "nif_in",
        x: 114,
        y: 181,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :pre_renewal,
        unique_name: "#Piano3",
        trigger: {1, 1}
      }
    ]

  @escaped 32

  @impl true
  def on_event("OnTouch_", ctx) do
    nif_esc = get_char_var(ctx, :nif_esc, 0)

    if nif_esc in [12, 13] or escaped?(ctx), do: escape(ctx, nif_esc), else: ctx
  end

  @impl true
  def on_talk(ctx), do: ctx

  defp escape(ctx, nif_esc) do
    ctx
    |> mes("^3355FFAs you bend towards")
    |> mes("the final empty key space")
    |> mes("to take a better look at it...^000000")
    |> next()
    |> soundeffect("complete.wav", 0)
    |> next()
    |> record_escape(nif_esc)
    |> mes("^3355FFYou begin to feel dizzy and")
    |> mes("your body feels as if it were")
    |> mes("floating in air. Then, your")
    |> mes("vision starts to blur...^000000")
    |> close2()
    |> warp("nif_in", 179, 163)
  end

  defp record_escape(ctx, 12) do
    ctx
    |> set_char_var(:MISC_QUEST, :erlang.bor(get_char_var(ctx, :MISC_QUEST, 0), @escaped))
    |> set_char_var(:nif_piano, 0)
  end

  defp record_escape(ctx, _nif_esc), do: ctx

  defp escaped?(ctx), do: :erlang.band(get_char_var(ctx, :MISC_QUEST, 0), @escaped) != 0
end
