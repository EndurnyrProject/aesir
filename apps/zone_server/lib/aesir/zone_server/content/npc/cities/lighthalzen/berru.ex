defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Berru do
  @moduledoc """
  Shows Berru and Pilia waiting anxiously for their missing father.

  ## Behavior

  - Randomly presents one of three exchanges about the siblings and their absent father.

  ## Credits

  - Original from rAthena, authors and Contributors
    - erKURITA
    - Au{R}oN (Translated by Alan)
    - $ephiroth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lighthalzen",
        x: 296,
        y: 239,
        dir: 3,
        sprite: 706,
        name: "Berru",
        scope: :shared,
        unique_name: "Berru#lhz_01"
      },
      %{
        map: "lighthalzen",
        x: 297,
        y: 239,
        dir: 3,
        sprite: 818,
        name: "Pilia",
        scope: :shared,
        unique_name: "Pilia#lhz_01"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case Enum.random(1..3) do
      1 ->
        ctx
        |> mes("[Berru]")
        |> mes("Daddy...! Waaaaah~!")
        |> mes("I wanna see my Daddy!")
        |> emotion(:cry)
        |> next()
        |> mes("[Pilia]")
        |> mes("Berru, I don't ")
        |> mes("think Daddy's coming")
        |> mes("home tonight. Come on,")
        |> mes("we should go to bed.")
        |> next()
        |> mes("[Berru]")
        |> mes("No, I'm not gonna")
        |> mes("sleep till Daddy gets")
        |> mes("home! He said he'll")
        |> mes("bring us candy tonight!")
        |> mes("You go sleep first, Pilia!")
        |> emotion(:anger)
        |> next()
        |> mes("[Pilia]")
        |> mes("^333333*Sigh...*^000000")
        |> mes("Where's our Daddy?")
        |> mes("He said he found a")
        |> mes("good job, but we haven't")
        |> mes("heard from him since then...")
        |> emotion(:think)
        |> close()

      2 ->
        ctx
        |> mes("[Pilia]")
        |> mes("What's taking him")
        |> mes("so long? I hope Daddy")
        |> mes("comes back home soon.")
        |> mes("Come on, Berru, don't cry.")
        |> emotion(:think)
        |> next()
        |> mes("[Berru]")
        |> mes("^333333*Sob...*^000000")
        |> mes("But I'm hungry")
        |> mes("and I miss Daddy!")
        |> next()
        |> mes("[Pilia]")
        |> mes("Uncle Togii from")
        |> mes("next door hasn't")
        |> mes("come back either...")
        |> close()

      3 ->
        ctx
        |> mes("[Pilia]")
        |> mes("Hmm? Oh, I'm sorry,")
        |> mes("but my little brother")
        |> mes("just won't stop crying.")
        |> mes("I'm sorry if we're loud...")
        |> emotion(:question)
        |> next()
        |> mes("[Pilia]")
        |> mes("Our daddy goes to work")
        |> mes("somewhere far away. He")
        |> mes("finally has a good job, but")
        |> mes("sometimes we don't hear")
        |> mes("from him for days. We get")
        |> mes("really worried about him.")
        |> next()
        |> mes("[Pilia]")
        |> mes("My brother Berru always")
        |> mes("misses him a lot. I don't")
        |> mes("know how to make him")
        |> mes("stop crying! What do I do?")
        |> emotion(:profusely_sweat)
        |> close()
    end
  end
end
