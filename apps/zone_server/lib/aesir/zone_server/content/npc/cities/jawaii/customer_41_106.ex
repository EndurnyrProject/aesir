defmodule Aesir.ZoneServer.Content.Npc.Cities.Jawaii.Customer41106 do
  @moduledoc """
  Shares Cage's opinion of marriage and the single life.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - DNett123
    - L0ne_w0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "jawaii_in",
        x: 41,
        y: 106,
        dir: 3,
        sprite: 98,
        name: "Customer",
        scope: :shared,
        unique_name: "Customer#Cage"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Cage]")

    if Rathena.truthy?(getpartnerid(ctx)) do
      mock_marriage(ctx)
    else
      celebrate_singlehood(ctx)
    end
  end

  defp mock_marriage(ctx) do
    ctx =
      ctx
      |> mes("....Bah!")
      |> mes("What are you so happy about?")
      |> mes("After all, everyone knows marriage is a sham for desperate, lonely people!")
      |> next()
      |> mes("[Cage]")

    ctx =
      if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
        ctx
        |> mes("I don't trust anybody!")
        |> mes("You're a fool for chaining")
        |> mes("yourself to some gorgeous")
        |> mes("woman for life!")
        |> mes("You hear me?!")
        |> mes("A FOOL!")
      else
        ctx
        |> mes("Look at you!")
        |> mes("You're a fool for")
        |> mes("chaining yourself to")
        |> mes("some pretty boy for life!")
        |> mes("You hear me?! A FOOL!")
      end

    ctx
    |> next()
    |> mes("[Cage]")
    |> mes("The single life is")
    |> mes("what it's all about!")
    |> mes("Women may break my")
    |> mes("spirit, but they'll never take...")
    |> mes("MY FREEDOM!")
    |> close()
  end

  defp celebrate_singlehood(ctx) do
    ctx
    |> mes("Drink, drink...!!")
    |> mes("Eat, eat...!!")
    |> mes("Join me,")
    |> mes("my brother")
    |> mes("in singlehood!")
    |> next()
    |> mes("[Cage]")
    |> mes("We are free...!")
    |> mes("We are free from")
    |> mes("the hell of marriage...!")
    |> mes("We are the sincere and")
    |> mes("competent singles...!")
    |> close()
  end
end
