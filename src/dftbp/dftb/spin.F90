!--------------------------------------------------------------------------------------------------!
!  DFTB+: general package for performing fast atomistic simulations                                !
!  Copyright (C) 2006 - 2025  DFTB+ developers group                                               !
!                                                                                                  !
!  See the LICENSE file for terms of usage and distribution.                                       !
!--------------------------------------------------------------------------------------------------!

#:include 'common.fypp'

!> Module containing various routines for spin polarised calculations. Intended to be used with SCC
!> switched on!
module dftbp_dftb_spin
  use dftbp_common_accuracy, only : dp
  use dftbp_type_commontypes, only : TOrbitals
  implicit none

  private
  public :: getEnergySpin, getSpinShift
  public :: Spin_getOrbitalEquiv, ud2qm, qm2ud


  !> Get the spin contribution to the energy
  interface getEnergySpin
    module procedure getEnergySpin_total
    module procedure getEnergySpin_atom
  end interface getEnergySpin


  !> Swap from up/down to charge/magnetisation
  interface ud2qm
    module procedure ud2qm2
    module procedure ud2qm3
    module procedure ud2qm4
  end interface ud2qm


  !> Swap from charge/magnetisation to up/down
  interface qm2ud
    module procedure qm2ud1
    module procedure qm2ud2
    module procedure qm2ud3
    module procedure qm2ud4
  end interface qm2ud

contains


  !> Constructs the spin-polarised shell shift from shift_l = sum_l' W_ll' p_l', where only the spin
  !> parts of the charges and shifts are processed.
  subroutine getSpinShift(shift, chargePerShell, species, orb, spinW)

    !> Resulting shell-shifts for the system
    real(dp), intent(out) :: shift(:,:,:)

    !> Spin resolved charges for each shell
    real(dp), intent(in) :: chargePerShell(:,:,:)

    !> Species of each atom
    integer, intent(in) :: species(:)

    !>  Information about the orbitals and their angular momenta
    type(TOrbitals), intent(in) :: orb

    !> Spin coupling constants.
    real(dp), intent(in) :: spinW(:,:,:)

    integer :: nAtom, iAtom, iSpecies, iShell, iShell2, nSpin, iSpin

    nAtom = size(chargePerShell, dim=2)
    @:ASSERT(nAtom > 0)
    @:ASSERT(size(shift,dim=2)==nAtom)
    @:ASSERT(all(shape(chargePerShell)==shape(shift)))
    nSpin = size(chargePerShell, dim=3)
    @:ASSERT(nSpin == 1 .or. nSpin == 3)

    shift(:,:,:) = 0.0_dp
    do iSpin = 1, nSpin
      do iAtom = 1, nAtom
        iSpecies = species(iAtom)
        do iShell = 1, orb%nShell(iSpecies)
          do iShell2 = 1, orb%nShell(iSpecies)
            shift(iShell, iAtom, iSpin) =  shift(iShell, iAtom, iSpin) + &
                & spinW(iShell, iShell2, iSpecies) * chargePerShell(iShell2, iAtom, iSpin)
          end do
        end do
      end do
    end do

  end subroutine getSpinShift


  !> Returns the total energy contribution of the spin polarisation
  subroutine getEnergySpin_total(rslt, chargePerShell, shiftPerShell)

    !> Contains the atomic contributions on exit
    real(dp), intent(out) :: rslt

    !> Spin resolved charges for each shell
    real(dp), intent(in) :: chargePerShell(:,:,:)

    !> Spin shift for each shell
    real(dp), intent(in) :: shiftPerShell(:,:,:)

    @:ASSERT(all(shape(chargePerShell)==shape(shiftPerShell)))
    @:ASSERT(size(chargePerShell,dim=3)>1 .and. size(chargePerShell,dim=3)<5)

    ! safe as the shift for the spin=0 component is 0 at the moment
    rslt = sum(chargePerShell(:,:,:)*shiftPerShell(:,:,:))

  end subroutine getEnergySpin_total


  !> Atom resolved part of the spin energy
  subroutine getEnergySpin_atom(rslt, chargePerShell, shiftPerShell)

    !> Contains the atomic contributions on exit
    real(dp), intent(out) :: rslt(:)

    !> Spin resolved charges for each shell
    real(dp), intent(in) :: chargePerShell(:,:,:)

    !> Spin shift for each shell
    real(dp), intent(in) :: shiftPerShell(:,:,:)

    @:ASSERT(size(rslt)==size(chargePerShell,dim=2))
    @:ASSERT(all(shape(chargePerShell)==shape(shiftPerShell)))
    @:ASSERT(size(chargePerShell,dim=3)>1 .and. size(chargePerShell,dim=3)<5)

    ! safe as the shift for the spin=0 component is 0 at the moment
    rslt(:) = sum(sum(chargePerShell(:,:,:)*shiftPerShell(:,:,:),dim=3),dim=1)

  end subroutine getEnergySpin_atom


  !> Returns the equivalence between the orbitals in the spin interaction.
  !> To do: Proper analysis of the spin coupling constants to watch for eventual equivalence:
  !> The current version assumes that no shells, only the orbitals inside each shell are equivalent,
  !> which is in most cases true anyway.
  subroutine Spin_getOrbitalEquiv(orb, species, equiv)

    !>  Information about the orbitals and their angular momenta
    type(TOrbitals), intent(in) :: orb

    !> Species of each atom
    integer, intent(in) :: species(:)

    !> The equivalence vector on return.
    integer, intent(out) :: equiv(:,:,:)

    integer :: nAtom, nSpin
    integer :: iAt, iOrb, iS, ind, iSp

    nAtom = size(equiv, dim=2)
    nSpin = size(equiv, dim=3)

    @:ASSERT(size(equiv, dim=1) == orb%mOrb)
    @:ASSERT(nSpin == 1 .or. nSpin == 2 .or. nSpin == 4)
    @:ASSERT(nAtom > 0)

    equiv(:,:,:) = 0
    ind = 1
    do iAt = 1, nAtom
      iSp = species(iAt)
      do iOrb = 1, orb%nOrbSpecies(iSp)
        equiv(iOrb, iAt, 1) = ind + orb%iShellOrb(iOrb, iSp) - 1
      end do
      ind = ind + orb%nShell(iSp)
    end do
    do iS = 2, nSpin
      ind = maxval(equiv)
      where (equiv(:,:,1) /= 0)
        equiv(:,:,iS) = equiv(:,:,1) + ind
      end where
    end do

  end subroutine Spin_getOrbitalEquiv


  !> Converts a charge/magnetization set into a up/down
  subroutine qm2ud1(x)

    !> Array of data [spin]
    real(dp), intent(inout) :: x(:)

    integer :: nSpin

    nSpin = size(x)
    @:ASSERT( nSpin == 1 .or. nSpin == 2 .or. nSpin == 4 )

    select case(nSpin)
    case (1)
      ! nothing to do
    case (2)
      x(1) = 0.5_dp * ( x(1) + x(2) )
      x(2) = x(1) - x(2)
    case (4)
      ! nothing to do
    end select

  end subroutine qm2ud1


  !> Converts a charge/magnetization set into a up/down
  subroutine qm2ud2(x)

    !> Array of data, last index spin
    real(dp), intent(inout) :: x(:,:)

    integer :: nSpin

    nSpin = size(x,dim=2)
    @:ASSERT( nSpin == 1 .or. nSpin == 2 .or. nSpin == 4 )

    select case(nSpin)
    case (1)
      ! nothing to do
    case (2)
      x(:,1) = 0.5_dp * ( x(:,1) + x(:,2) )
      x(:,2) = x(:,1) - x(:,2)
    case (4)
      ! nothing to do
    end select

  end subroutine qm2ud2


  !> Converts a charge/magnetization set into a up/down
  subroutine qm2ud3(x)

    !> Array of data, last index spin
    real(dp), intent(inout) :: x(:,:,:)

    integer :: nSpin

    nSpin = size(x,dim=3)
    @:ASSERT( nSpin == 1 .or. nSpin == 2 .or. nSpin == 4)

    select case(nSpin)
    case (1)
      ! nothing to do
    case (2)
      x(:,:,1) = 0.5_dp * ( x(:,:,1) + x(:,:,2) )
      x(:,:,2) = x(:,:,1) - x(:,:,2)
    case (4)
      ! nothing to do
    end select

  end subroutine qm2ud3


  !> Converts a charge/magnetization set into a up/down
  subroutine qm2ud4(x)

    !> Array of data, last index spin
    real(dp), intent(inout) :: x(:,:,:,:)

    integer :: nSpin

    nSpin = size(x,dim=4)
    @:ASSERT( nSpin == 1 .or. nSpin == 2 .or. nSpin == 4)

    select case(nSpin)
    case (1)
      ! nothing to do
    case(2)
      x(:,:,:,1) = 0.5_dp * ( x(:,:,:,1) + x(:,:,:,2) )
      x(:,:,:,2) = x(:,:,:,1) - x(:,:,:,2)
    case (4)
      ! nothing to do
    end select

  end subroutine qm2ud4


  !> Converts a up/down set into a charge/magnetization
  subroutine ud2qm2(x)

    !> Array of data, last index spin
    real(dp), intent(inout) :: x(:,:)

    integer :: nSpin

    nSpin = size(x,dim=2)
    @:ASSERT( nSpin == 1 .or. nSpin == 2 .or. nSpin == 4)

    select case(nSpin)
    case (1)
      ! nothing to do
    case (2)
      x(:,1) = x(:,1) + x(:,2)
      x(:,2) = x(:,1) - 2.0_dp * x(:,2)
    case (4)
      ! nothing to do
    end select

  end subroutine ud2qm2


  !> Converts a up/down set into a charge/magnetization
  subroutine ud2qm3(x)

    !> Array of data, last index spin
    real(dp), intent(inout) :: x(:,:,:)

    integer :: nSpin

    nSpin = size(x,dim=3)
    @:ASSERT( nSpin == 1 .or. nSpin == 2 .or. nSpin == 4 )

    select case(nSpin)
    case (1)
      ! nothing to do
    case (2)
      x(:,:,1) = x(:,:,1) + x(:,:,2)
      x(:,:,2) = x(:,:,1) - 2.0_dp * x(:,:,2)
    case (4)
      ! nothing to do
    end select

  end subroutine ud2qm3


  !> Converts a charge/magnetization set into a up/down
  subroutine ud2qm4(x)

    !> Array of data, last index spin
    real(dp), intent(inout) :: x(:,:,:,:)

    integer :: nSpin

    nSpin = size(x,dim=4)
    @:ASSERT( nSpin == 1 .or. nSpin == 2 .or. nSpin == 4)

    select case(nSpin)
    case (1)
      ! nothing to do
    case (2)
      x(:,:,:,1) = x(:,:,:,1) +          x(:,:,:,2)
      x(:,:,:,2) = x(:,:,:,1) - 2.0_dp * x(:,:,:,2)
    case (4)
      ! nothing to do
    end select

  end subroutine ud2qm4

end module dftbp_dftb_spin
