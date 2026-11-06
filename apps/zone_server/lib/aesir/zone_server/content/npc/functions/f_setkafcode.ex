defmodule Aesir.ZoneServer.Content.Npc.Functions.FSetkafcode do
  @moduledoc """
  Sets, changes or removes the storage password.

  ## Behavior

  Without a password the Kafra offers to set one for 5000 zeny. With a password the player may
  change it (verifying the old one first) or remove it for 1000 zeny; a wrong password keeps the
  current one and the removal fee. Every failure shows the matching emotion and returns to the
  menu.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script kafras/functions_kafras.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Content.Npc.Functions.FEntkafcode
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @set_fee 5000
  @removal_fee 1000

  @doc """
  Callable rAthena global function `F_SetKafCode(npc_name, company_name)`; throws
  `{:script_end, ctx}` when the dialog closes.
  """
  @spec call(Ctx.t(), [term()]) :: no_return()
  def call(ctx, args) do
    name = Enum.at(args, 0, 0)
    company = Enum.at(args, 1, 0)

    ctx = mes(ctx, name)

    if get_account_var(ctx, "#kafra_code", 0) == 0 do
      offer_password(ctx, name, company)
    else
      manage_password(ctx, name, company)
    end
  end

  defp offer_password(ctx, name, company) do
    {ctx, choice} =
      ctx
      |> mes("#{company} proudly presents you a new service:")
      |> mes("Additional storage protection with a password.")
      |> next()
      |> select(["Set new password -> 5000z", "Cancel"])

    ctx =
      if choice == 1 do
        {ctx, _code} = set_password(ctx, name, company)
        ctx
      else
        ctx
      end

    halt(ctx |> close() |> cutin("", 255))
  end

  defp manage_password(ctx, name, company) do
    {ctx, choice} =
      ctx
      |> mes("Your storage is protected with a password. What would you do now?")
      |> next()
      |> select(["Change old password -> 5000z", "Remove storage password -> 1000z", "Cancel"])

    ctx =
      try do
        case choice do
          1 -> change_password(ctx, name, company)
          2 -> remove_password(ctx, name, company)
          3 -> ctx
          _other -> halt(ctx)
        end
      catch
        :throw, {:brk_1, ctx} -> ctx
      end

    halt(ctx |> close() |> cutin("", 255))
  end

  defp change_password(ctx, name, company) do
    {ctx, code} =
      ctx
      |> mes(name)
      |> mes("At first, please enter your ^0000FFold password^000000.")
      |> FEntkafcode.call([])

    if not Rathena.truthy?(code) or code != get_account_var(ctx, "#kafra_code", 0) do
      ctx
      |> mes("Wrong password. You can't set a new password.")
      |> emotion(:scratch)
      |> brk()
    else
      {ctx, _new_code} = set_password(next(ctx), name, company)
      ctx
    end
  end

  defp remove_password(ctx, name, company) do
    {ctx, code} =
      ctx
      |> mes(name)
      |> mes("Please, enter your password before its removal.")
      |> FEntkafcode.call([])

    cond do
      not Rathena.truthy?(code) ->
        ctx
        |> mes("The password hasn't been removed.")
        |> emotion(:scratch)
        |> brk()

      true ->
        remove_confirmed(ctx |> next() |> mes(name), code, company)
    end
  end

  defp remove_confirmed(ctx, code, company) do
    if zeny(ctx) < @removal_fee do
      ctx
      |> mes("You don't have enough zeny.")
      |> emotion(:money)
      |> brk()
    else
      ctx = pay_zeny(ctx, @removal_fee)

      if code == get_account_var(ctx, "#kafra_code", 0) do
        ctx
        |> set_account_var("#kafra_code", 0)
        |> mes("You've successfully cleared your storage password.")
        |> mes("Thank you for using #{company}.")
        |> emotion(:thanks)
      else
        ctx
        |> mes("Wrong password. We won't return your 1000z.")
        |> mes("Please, next time enter correct password.")
        |> emotion(:sorry)
      end
    end
  end

  defp set_password(ctx, name, company) do
    {ctx, code} =
      ctx
      |> mes(name)
      |> mes("Now enter your ^FF0000new password^000000 to protect your storage from thieves.")
      |> FEntkafcode.call([])

    if not Rathena.truthy?(code) do
      {mes(ctx, "The password hasn't been changed.") |> emotion(:scratch), nil}
    else
      store_password(next(ctx) |> mes(name), code, company)
    end
  end

  defp store_password(ctx, code, company) do
    if zeny(ctx) < @set_fee do
      {mes(ctx, "You don't have enough zeny.") |> emotion(:money), nil}
    else
      ctx =
        ctx
        |> pay_zeny(@set_fee)
        |> set_account_var("#kafra_code", code)
        |> mes("You've protected your storage with a secret password.")
        |> mes("Thank you for using #{company}.")
        |> emotion(:thanks)

      {ctx, nil}
    end
  end

  defp halt(ctx), do: throw({:script_end, ctx})
  defp brk(ctx), do: throw({:brk_1, ctx})
end
