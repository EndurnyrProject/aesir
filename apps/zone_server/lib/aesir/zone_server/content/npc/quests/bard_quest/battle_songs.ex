defmodule Aesir.ZoneServer.Content.Npc.Quests.BardQuest.BattleSongs do
  @moduledoc """
  A book containing a song for soldiers.

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
        y: 94,
        dir: 0,
        sprite: 111,
        name: "Battle Songs",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :gef_bard_q, 0) > 11 do
      ctx
      |> mes("[Drumming in the battlefield]")
      |> mes("This song was written to give courage to soldiers on the battlefield.")
      |> next()
      |> mes("[Drumming in the battlefield]")
      |> mes("The sounds of galloping")
      |> mes("Echo in the distance.")
      |> mes("A cloud of hazy dust")
      |> next()
      |> mes("[Drumming in the battlefield]")
      |> mes("Fills the setting sun.")
      |> mes("Thousands of eyes open")
      |> mes("Torches on the castle")
      |> mes("Flare like thousands of Ifrits.")
      |> next()
      |> mes("[Drumming in the battlefield]")
      |> mes("Hear the throbbing of my heart,")
      |> mes("The blood flowing in my veins.")
      |> mes("Feeling the heaviness of my armor.")
      |> mes("The enemy has appeared before us.")
      |> next()
      |> mes("[Drumming in the battlefield]")
      |> mes("Beat the drums hard, harder!")
      |> mes("Courage, soldiers, march forward!")
      |> mes("Shout loud, soldiers, louder!")
      |> mes("Today will never come back!")
      |> next()
      |> mes("[Drumming in the battlefield]")
      |> mes("Stun the sky")
      |> mes("Provoke the earth,")
      |> mes("I feel my heartbeat again.")
      |> mes("Blow the bugle to")
      |> mes("Sway the fortress.")
      |> mes("Today will never come back!")
      |> close()
    else
      ctx
      |> mes("[Sketzi Bundin]")
      |> mes("I'm sorry, but that book is not available for public exhibition.")
      |> close()
    end
  end
end
