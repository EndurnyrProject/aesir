defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNiflheim.Alreg do
  @moduledoc """
  A hungry Niflheim ghoul who bites players and, on the first bite, starts the Piano Key quest.

  ## Behavior

  - Always clears the legacy piano variable, then bites the player.
  - Before the quest has started, the bite takes 60% HP, rewards the first Piano Keyboard and
    randomly picks which of the two key routes the player follows.
  - Otherwise the bite takes 30% HP with no reward.

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
        map: "niflheim",
        x: 224,
        y: 243,
        dir: 3,
        sprite: 795,
        name: "Alreg",
        scope: :shared,
        unique_name: "Alreg#nif"
      }
    ]

  @piano_keyboard 7184
  @escaped 32

  @impl true
  def on_talk(ctx) do
    ctx =
      if get_char_var(ctx, :nif_piano, 0) != 0, do: set_char_var(ctx, :nif_piano, 0), else: ctx

    ctx =
      ctx
      |> mes("[Alreg]")
      |> mes("Me like meat, muheh.")
      |> mes("You! Look tempting.")
      |> next()
      |> mes("[Alreg]")
      |> mes("Me want to taste you.")
      |> next()
      |> mes("^FF3355*Crunch* Crunch*^000000")

    if quest_not_started?(ctx), do: first_bite(ctx), else: bite(ctx)
  end

  defp first_bite(ctx) do
    ctx = ctx |> percent_heal(hp: -60, sp: 0) |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("NooOOoOOoOoO~!")
    |> next()
    |> mes("[Alreg]")
    |> mes("It long time since I had meat")
    |> mes("so... so good. You taste")
    |> mes("good. Alreg give you this")
    |> mes("for payback. Present!")
    |> mes("*Burrrp*")
    |> set_char_var(:nif_esc, Enum.random(1..2))
    |> give_item(@piano_keyboard, 1)
    |> close()
  end

  defp bite(ctx) do
    ctx = ctx |> percent_heal(hp: -30, sp: 0) |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Ow~! What are you")
    |> mes("trying to do, kill me?!")
    |> next()
    |> mes("[Alreg]")
    |> mes("Hm? Oh, no no no.")
    |> mes("Me am trying to eat you.")
    |> close()
  end

  defp quest_not_started?(ctx) do
    get_char_var(ctx, :nif_esc, 0) == 0 and
      :erlang.band(get_char_var(ctx, :MISC_QUEST, 0), @escaped) == 0
  end
end
