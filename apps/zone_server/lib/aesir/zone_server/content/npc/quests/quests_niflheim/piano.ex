defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNiflheim.Piano do
  @moduledoc """
  The big Niflheim piano with missing keys, where Piano Key questers insert the keys they found.

  ## Behavior

  - Before the quest starts, touching it describes the seven missing keys.
  - With the route complete and six Piano Keyboards, it takes the keys and reveals that one
    last key space remains.

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
      %{
        map: "nif_in",
        x: 115,
        y: 181,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#Piano",
        trigger: {1, 1}
      }
    ]

  @piano_keyboard 7184
  @escaped 32

  @impl true
  def on_event("OnTouch_", ctx) do
    nif_esc = get_char_var(ctx, :nif_esc, 0)

    cond do
      nif_esc == 0 and :erlang.band(get_char_var(ctx, :MISC_QUEST, 0), @escaped) == 0 ->
        describe(ctx)

      nif_esc == 11 and count_item(ctx, @piano_keyboard) > 5 ->
        insert_keys(ctx)

      true ->
        ctx
    end
  end

  @impl true
  def on_talk(ctx), do: ctx

  defp describe(ctx) do
    ctx
    |> mes("^3355FFYou see a big, heavy piano.")
    |> mes("You get the feeling that")
    |> mes("its music would sound magnificient.^000000")
    |> next()
    |> mes("^3355FFAs you examine the piano,")
    |> mes("you find that 7 keys")
    |> mes("are missing in the")
    |> mes("middle of the keyboard.")
    |> mes("If you had all the keys,")
    |> mes("you could play music...^000000")
    |> close()
  end

  defp insert_keys(ctx) do
    ctx
    |> set_char_var(:nif_esc, 12)
    |> delitem(@piano_keyboard, 6)
    |> mes("^3355FFYou took the keys you've found")
    |> mes("and inserted them into")
    |> mes("each empty space.^000000")
    |> next()
    |> mes("^3355FFBut then you realize")
    |> mes("that you're missing the last")
    |> mes("key for the space on the far")
    |> mes("left of the keyboard...^000000")
    |> close()
  end
end
