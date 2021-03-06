
module generate_ham
  !! This module contains parameters to control the actions of wannier90.
  !! Also routines to read the parameters and write them out again.

  use constants, only: dp
  use io, only: stdout, maxlen
  use read_inputs 

  implicit none

  integer, allocatable, save :: tran(:,:)

contains

  subroutine generate_hamr_from_TB()
    use constants
    use io
    use comms, only: my_node_id, num_nodes, comms_array_split,comms_allreduce
   
    implicit none

    character(len=1) :: header
    logical :: iffile
    integer :: i,j,rx,ry,rz,x,y,z,r,ierr,tmp_i,tmp_j
    integer :: nbmin,nbmax,num_band_max 
    ! Needed to split an array on different nodes
    integer, dimension(0:num_nodes - 1) :: counts
    integer, dimension(0:num_nodes - 1) :: displs
    real(kind=dp) :: H_re,H_im
    integer, allocatable :: ndegen(:)
!    complex(kind=dp), allocatable :: Hk(:,:)
!    complex(kind=dp), allocatable :: dHk(:,:)

    inquire(file='wannier90_hr.dat',exist=iffile)
    if (iffile.eqv. .false.)then
       write(*,*) 'wannier90_hr.dat must be present!!'
       STOP
    else
       open(unit=20,file='wannier90_hr.dat',status='old',form='formatted')
       read(20,*) header
       read(20,*) num_wann
       read(20,*) nR
       if (.not. allocated(tran)) then
         allocate (tran(3,nR), stat=ierr)
         if (ierr /= 0) call io_error('Error allocating tran in generate_hamr')
       endif
       if (.not. allocated(ndegen)) then
         allocate (ndegen(nR), stat=ierr)
         if (ierr /= 0) call io_error('Error allocating ndegen in generate_hamr')
       endif
       if (.not. allocated(HamR)) then
         allocate (HamR(nR,num_wann,num_wann), stat=ierr)
         if (ierr /= 0) call io_error('Error allocating HamR in generate_hamr')
       endif
       ndegen=0
       read(20,*) (ndegen(r), r=1,nR) 
       tran=0
       HamR=cmplx_0
       do r=1,nR
         do i=1,num_wann
           do j=1,num_wann
             read(20,*) x,y,z,tmp_i,tmp_j,H_re,H_im
             if (i.eq.1 .and. j.eq.1) then
               tran(1,r)=x;tran(2,r)=y;tran(3,r)=z
             endif
             HamR(r,j,i)=dcmplx(H_re,H_im)
           enddo
         enddo
       enddo
       close(20)
    endif

    inquire(file='wannier90_dhr.dat',exist=iffile)
    if (iffile.eqv. .true.)then
       dHamR=cmplx_0
       lforce=.true.
       open(unit=20,file='wannier90_dhr.dat',status='old',form='formatted')
       read(20,*) header
       read(20,*) num_wann
       read(20,*) nR
       if (.not. allocated(tran)) then
         allocate (tran(3,nR), stat=ierr)
         if (ierr /= 0) call io_error('Error allocating tran in generate_hamr')
       endif
       if (.not. allocated(ndegen)) then
         allocate (ndegen(nR), stat=ierr)
         if (ierr /= 0) call io_error('Error allocating ndegen in generate_hamr')
       endif
       if (.not. allocated(dHamR)) then
         allocate (dHamR(nR,num_wann,num_wann), stat=ierr)
         if (ierr /= 0) call io_error('Error allocating dHamR in generate_hamr')
       endif
       ndegen=0
       read(20,*) (ndegen(r), r=1,nR) 
       tran=0
       dHamR=cmplx_0
       do r=1,nR
         do i=1,num_wann
           do j=1,num_wann
             read(20,*) x,y,z,tmp_i,tmp_j,H_re,H_im
             if (i.eq.1 .and. j.eq.1) then
               tran(1,r)=x;tran(2,r)=y;tran(3,r)=z
             endif
             dHamR(r,j,i)=dcmplx(H_re,H_im)
           enddo
         enddo
       enddo
       close(20)
    endif

    !if (lforce.eq..true.) dHamR=cmplx_0

  end subroutine generate_hamr_from_TB
 
  subroutine generate_hamr()
    use constants
    use io
    use comms, only: my_node_id, num_nodes, comms_array_split,comms_allreduce
   
    implicit none

    integer :: i,j,rx,ry,rz,x,y,z,r,ierr
    integer :: nbmin,nbmax,num_band_max 
    ! Needed to split an array on different nodes
    integer, dimension(0:num_nodes - 1) :: counts
    integer, dimension(0:num_nodes - 1) :: displs
    real(kind=dp) :: rdotk
    complex(kind=dp), allocatable :: Hk(:,:)
    complex(kind=dp), allocatable :: dHk(:,:)


    rx=mp_grid(1)/2;ry=mp_grid(2)/2;rz=mp_grid(3)/2
    nR=(2*rx+1)*(2*ry+1)*(2*rz+1)
    if (.not. allocated(tran)) then
      allocate (tran(3,nR), stat=ierr)
      if (ierr /= 0) call io_error('Error allocating tran in generate_hamr')
    endif
    if (.not. allocated(Hk)) then
      allocate (Hk(num_wann,num_wann), stat=ierr)
      if (ierr /= 0) call io_error('Error allocating Hk in generate_hamr')
    endif
    if (.not. allocated(HamR)) then
      allocate (HamR(nR,num_wann,num_wann), stat=ierr)
      if (ierr /= 0) call io_error('Error allocating HamR in generate_hamr')
    endif
    if (lforce.eqv..true.) then
      if (.not. allocated(dHk)) then
        allocate (dHk(num_wann,num_wann), stat=ierr)
        if (ierr /= 0) call io_error('Error allocating Hk in generate_hamr')
      endif
      if (.not. allocated(dHamR)) then
        allocate (dHamR(nR,num_wann,num_wann), stat=ierr)
        if (ierr /= 0) call io_error('Error allocating HamR in generate_hamr')
      endif
    endif
      
    tran=0
    r=0
    do x=-rx,rx
      do y=-ry,ry
        do z=-rz,rz
          r=r+1
          tran(1,r)=x;tran(2,r)=y;tran(3,r)=z
        enddo
      enddo
    enddo

    call comms_array_split(num_kpts, counts, displs)    
    !write(*,*) my_node_id, counts(my_node_id), displs(my_node_id)

    HamR=cmplx_0
    if (lforce.eqv..true.) dHamR=cmplx_0
    do i=displs(my_node_id)+1,displs(my_node_id)+counts(my_node_id)
      nbmin=band_win(1,i)
      nbmax=band_win(2,i)
      num_band_max=nbmax-nbmin+1
      Hk=cmplx_0
      if (lforce.eqv..true.) dHk=cmplx_0
      do x=1,num_wann
        do y=1,num_wann
          do z=1,num_band_max
            Hk(x,y)=Hk(x,y)+dconjg(UMatrix(z,x,i))*UMatrix(z,y,i)*eigvals(nbmin+z-1,i)
            if (lforce.eqv..true.) dHk(x,y)=dHk(x,y)+dconjg(UMatrix(z,x,i))*UMatrix(z,y,i)*deig(nbmin+z-1,i)
          enddo
        enddo
      enddo
      !do z=1,num_band_max
      !  write(*,*) i, eigvals(nbmin+z-1,i), UMatrix(z,1,i) 
      !enddo
       
      do r=1,nR
        rdotk=-1*twopi*dot_product(kpt_latt(:,i),dfloat(tran(:,r)))
        HamR(r,:,:)=HamR(r,:,:)+Hk*exp(cmplx_i*rdotk)
        if (lforce.eqv..true.) dHamR(r,:,:)=dHamR(r,:,:)+dHk*exp(cmplx_i*rdotk)
      enddo
    enddo
    call comms_allreduce(HamR,nR,num_wann,num_wann,'SUM')
    HamR=HamR/dfloat(num_kpts)
    if (lforce.eqv..true.) then
      call comms_allreduce(dHamR,nR,num_wann,num_wann,'SUM')
      dHamR=dHamR/dfloat(num_kpts)
    endif
    !write(*,*) HamR(365,1,1)
    !if (allocated(tran)) deallocate (tran)
    if (allocated(Hk)) deallocate (Hk)
    if ((lforce.eqv..true.) .and. (allocated(dHk))) deallocate (dHk)

  end subroutine generate_hamr

end module generate_ham
 
