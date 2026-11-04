defmodule Aesir.ZoneServer.Content.Npc.Quests.BardQuest.AppleOfIdun do
  @moduledoc """
  A book containing the song Apple of Idun.

  ## Behavior

  - Allows access to the song after the bard quest reaches the required stage.

  ## Credits

  - Original from rAthena, authors Riotblade and L0ne_W0lf; contributors Lupus, SinSloth, and Euphy.

  ## Adaptation

  - Transpiled by `mix aesir.import.npcs` from rAthena script.
  - LLM-assisted Elixir refactor.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_in01",
        x: 173,
        y: 92,
        dir: 0,
        sprite: 111,
        name: "Apple of Idun",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :gef_bard_q, 0) > 11 do
      ctx
      |> mes("[Apple of Idun]")
      |> mes(
        "This song praises the golden apples of the goddess Idun. These were the source of the God's power, as it prevented them from growing old."
      )
      |> next()
      |> mes("[Apple of Idun]")
      |> mes("Every god never grows old")
      |> mes("Because of beautiful")
      |> mes("Goddess, Idun.")
      |> mes("Keeper of the apples of youth")
      |> mes("Goddess of immortality.")
      |> next()
      |> mes("[Apple of Idun]")
      |> mes("Every god never grows old.")
      |> mes("Idun, the wife of Bragi,")
      |> mes("Idun, Odin's daughter in law~")
      |> mes("The apples she keeps")
      |> mes("In her basket.")
      |> next()
      |> mes("[Apple of Idun]")
      |> mes("Without Idun,")
      |> mes("Every god would")
      |> mes("have succumbed to age.")
      |> next()
      |> mes("[Apple of Idun]")
      |> mes("Even Thor, the strongest of gods,")
      |> mes("would grow frail, Megingjard would")
      |> mes("slip from his waist, and Mjolnir")
      |> mes("would never fly again.")
      |> next()
      |> mes("[Apple of Idun]")
      |> mes("Without Idun,")
      |> mes("Every god would")
      |> mes("have succumbed to age.")
      |> mes("Loki was careless once,")
      |> mes("and made her lost to the gods.")
      |> mes("Loki was forced to get her back.")
      |> next()
      |> mes("[Apple of Idun]")
      |> mes("My goddess stands")
      |> mes("In the field of Asgard")
      |> mes("She hands me fruit from heaven.")
      |> mes("You will be loved by every god...")
      |> mes("You will be blessed")
      |> mes("By every god...")
      |> next()
      |> mes("[Apple of Idun]")
      |> mes("If you share the")
      |> mes("Apple of youth with me")
      |> mes("Even a bite of it with")
      |> mes("This poor poet.")
      |> next()
      |> mes("[Apple of Idun]")
      |> mes("You will be loved by every god...")
      |> mes("You will be blessed")
      |> mes("By every god...")
      |> close()
    else
      ctx
      |> mes("[Sketzi Bundin]")
      |> mes("I'm sorry, but that book is not available for public exhibition.")
      |> close()
    end
  end
end
