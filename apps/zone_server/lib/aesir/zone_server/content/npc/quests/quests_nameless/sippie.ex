defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Sippie do
  @moduledoc """
  Sippie shares her thoughts on High Priestess Niren.

  ## Behavior

  - Discusses Niren and the pope during the Arunafeltz quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ra_temple",
        x: 168,
        y: 54,
        dir: 3,
        sprite: 917,
        name: "Sippie",
        scope: :shared,
        unique_name: "Sippie#ss"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Sippie]")
      |> mes("Now I finally have some")
      |> mes("time to take a break.")
      |> mes("Too many followers are")
      |> mes("crowding High Priestess")
      |> mes("Niren, and they're giving")
      |> mes("me so much work to do!")

    if get_char_var(ctx, :aru_em, 0) == 11 do
      ctx
      |> next()
      |> mes("[Sippie]")
      |> mes("Excuse me, but are you")
      |> mes("a friend of our pope?")
      |> mes("I think I saw you talk")
      |> mes("to her a while ago...")
      |> next()
      |> mes("[Sippie]")
      |> mes("I don't understand why")
      |> mes("High Priestess Niren wants")
      |> mes("to go to war. I actually think")
      |> mes("that in her heart, she doesn't")
      |> mes("want it. She's sweet and kind")
      |> mes("once you get to know her.")
      |> next()
      |> mes("[Sippie]")
      |> mes("She loves children...")
      |> mes("She's like a mother to")
      |> mes("all the kids in Arunafeltz.")
      |> mes("She even brought our pope to")
      |> mes("Rachel when she was a baby,")
      |> mes("raising her like her own child.")
      |> next()
      |> mes("[Sippie]")
      |> mes("If you didn't know she")
      |> mes("was our pope, it'd be easy")
      |> mes("to mistake her for High")
      |> mes("Priestess Niren's daughter.")
      |> close()
    else
      close(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
