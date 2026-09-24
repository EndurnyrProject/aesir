defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Priest.Doppelganger do
  @moduledoc """
  Demon that tempts Acolytes to abandon the Priest spiritual training.

  ## Behavior

  - Warns off Priests who pass through.
  - Twice offers Acolytes a return to Novice; accepting either offer warps them out of the
    training.
  - Refusing both offers lets the Acolyte continue.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Pgro Team (OwNaGe)
    - kobra_k88
    - Lupus
    - Vicious
    - KarLaeda
    - L0ne_W0lf
    - Samuray22
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "job_prist",
        x: 168,
        y: 80,
        dir: 4,
        sprite: 1046,
        name: "Doppelganger",
        scope: :shared,
        unique_name: "Doppelganger#prst",
        trigger: {8, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:priest) -> warn_priest(ctx)
      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:acolyte) -> tempt_acolyte(ctx)
      true -> ctx
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp warn_priest(ctx) do
    ctx
    |> mes("[Doppelganger]")
    |> mes(
      "What are you doing here? You've already made your choice, there's no going back... Priest."
    )
    |> next()
    |> mes("[Doppelganger]")
    |> mes(
      "Besides, this is none of your business. Whether or not this Acolyte becomes a Priest isn't up to you. Now get out of here, before I get violent."
    )
    |> close()
  end

  defp tempt_acolyte(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Doppelganger]")
      |> mes("Hold on there, Acolyte.")
      |> mes("I'm not like Deviruchi,")
      |> mes("so I won't mince")
      |> mes("words with you.")
      |> next()
      |> mes("[Doppelganger]")
      |> mes(
        "Now, why would you want to become a Priest? It's such a worthless, thankless job. If you want, I'll give you the chance to become a Novice. Then you can become something much better!"
      )
      |> next()
      |> mes("[Doppelganger]")
      |> mes(
        "Of course, I'll let you redistribute your stat points by your base level. Now, isn't that a sweet deal...?"
      )
      |> next()
      |> select(["Deal, Deal!", "No deal... Doppelganger."])

    if choice == 1 do
      ctx
      |> mes("[Doppelganger]")
      |> mes("Good choice~")
      |> mes("I shall return your")
      |> mes("job to a Novice")
      |> mes("as you wish.")
      |> next()
      |> banish()
    else
      repeat_offer(ctx)
    end
  end

  defp repeat_offer(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Doppelganger]")
      |> mes(
        "I don't think you understood what I just offered. Think about it again. I mean, this is your one and only chance to undo your life mistakes. I mean, becoming an Acolyte?"
      )
      |> next()
      |> mes("[Doppelganger]")
      |> mes(
        "Just don't become a Priest. I won't ask you more than once. Then you can choose a better job... perhaps a Swordman like me."
      )
      |> next()
      |> select(["I don't want to be a Priest!", "I'll never listen to you!"])

    if choice == 1 do
      ctx
      |> mes("[Doppelganger]")
      |> mes(
        "Excellent choice. Now, never return to this place. I shall return your job to Novice as you wish."
      )
      |> next()
      |> banish()
    else
      ctx
      |> mes("[Doppelganger]")
      |> mes("Hmpf. I admire")
      |> mes("your determination.")
      |> mes("Okay, you can pass.")
      |> mes("For now.")
      |> next()
      |> mes("[Doppelganger]")
      |> mes("But if by chance we meet again,")
      |> mes("I assure you... You won't be happy at all to see me.")
      |> close()
    end
  end

  defp banish(ctx) do
    ctx
    |> mes("[Doppelganger]")
    |> mes("Now go!!")
    |> mes("Never step into")
    |> mes("the light again!")
    |> close()
    |> warp("gef_dun02", 210, 177)
  end
end
